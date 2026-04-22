#!/bin/bash
# --------------------------------------------------------------
# Script to map paired-end reads (WGS) using Bowtie2 + Samtools
# Robust for HPC: controls memory/tmp for samtools sort and avoids "Too many open files"
# --------------------------------------------------------------
# Usage: ./mapping_wgs.sh <sample_id> <reference> <workdir> <threads> [I=200] [X=400]
# Example:
# ./mapping_wgs.sh IND01 /path/reference.fasta /path/results 32
# --------------------------------------------------------------

set -euo pipefail

# --------------------------------------------------------------
# Validate minimum number of arguments
# --------------------------------------------------------------
if [ $# -lt 4 ]; then
  echo "USAGE: $0 <sample_id> <reference> <workdir> <threads> [I=200] [X=400]"
  exit 1
fi

# --------------------------------------------------------------
# Load configuration if available (standalone execution support)
# --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_BASE="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ -f "$SUITE_BASE/lib/load_config.sh" ]]; then
    source "$SUITE_BASE/lib/load_config.sh"
fi

# --------------------------------------------------------------
# Inputs and parameters
# --------------------------------------------------------------
sample="$1"
reference="$2"
workdir="$3"
threads="${4:-$DEFAULT_PROC}"
i="${5:-$DEFAULT_I}"
x="${6:-$DEFAULT_X}"
read_group="SM:${sample}"

# --------------------------------------------------------------
# Verify reference
# --------------------------------------------------------------
if [ ! -f "$reference" ]; then
  echo "ERROR: Reference does not exist: $reference"
  exit 2
fi

# --------------------------------------------------------------
# Find Sample ID (WGS)
# --------------------------------------------------------------
# Using BIODATA_WGS and CONSECUTIVOS_FILE defined in config
sample_id_wgs=$(awk -v sample_name="${sample}" '{if ($2==sample_name) print $1}' "${CONSECUTIVOS_FILE:-/biodata2/HTS/WGS/consecutivosEI-Cenicana.txt}" || true)
if [ -z "${sample_id_wgs}" ]; then
  echo "ERROR: Could not find ID for sample '${sample}' in ${CONSECUTIVOS_FILE:-/biodata2/HTS/WGS/consecutivosEI-Cenicana.txt}"
  exit 2
fi


# --------------------------------------------------------------
# Build index prefix robustly
# --------------------------------------------------------------
directory="$(dirname "$reference")"
ref_base="$(basename "$reference")"
ref_base="${ref_base%.gz}"
ref_base="${ref_base%.fasta}"
ref_base="${ref_base%.fa}"
ref_base="${ref_base%.fna}"
INDEXES="${directory}/${ref_base}"

# --------------------------------------------------------------
# Prepare output
# --------------------------------------------------------------
output_dir="${workdir}/${ref_base}"
mkdir -p "$output_dir"

sorted_bam="${output_dir}/${sample}_sorted.bam"
log_bt2="${output_dir}/${sample}_bowtie2.log"

# --------------------------------------------------------------
# Validate indexes (.bt2 or .bt2l)
# --------------------------------------------------------------
if [ ! -f "${INDEXES}.1.bt2" ] && [ ! -f "${INDEXES}.1.bt2l" ]; then
  echo "ERROR: Bowtie2 index not found with prefix:"
  echo "  ${INDEXES}"
  echo "Expected to find:"
  echo "  ${INDEXES}.1.bt2  or  ${INDEXES}.1.bt2l"
  exit 3
fi

# --------------------------------------------------------------
# Input paths (reads)
# --------------------------------------------------------------
f1="/biodata2/HTS/WGS/${sample_id_wgs}/${sample_id_wgs}_R1.fastq.gz"
f2="/biodata2/HTS/WGS/${sample_id_wgs}/${sample_id_wgs}_R2.fastq.gz"

if [ ! -f "$f1" ] || [ ! -f "$f2" ]; then
  echo "ERROR: Expected FASTQ files not found:"
  echo "  - $f1"
  echo "  - $f2"
  exit 4
fi

# --------------------------------------------------------------
# Skip processing if sorted BAM already exists
# --------------------------------------------------------------
if [ -f "$sorted_bam" ]; then
  echo "Sorted BAM file already exists: $sorted_bam"
  echo "Skipping process for ${sample}."
  exit 0
fi

echo "Working directory: $output_dir"
echo "Bowtie2 index (prefix): $INDEXES"
echo "Reads:"
echo "  R1: $f1"
echo "  R2: $f2"

# --------------------------------------------------------------
# Robust settings for samtools sort
#   - Limits sort threads (max 32) even if Bowtie2 uses more
#   - Assigns memory per thread to avoid thousands of temporaries
#   - Uses local TMPDIR if exists for temporaries
#   - Attempts to increase ulimit -n if allowed
# --------------------------------------------------------------
tmp_root="${TMPDIR:-${output_dir}/tmp}"
tmp_dir="${tmp_root}/${sample}_samtools_tmp"
mkdir -p "$tmp_dir"

ulimit -n 65535 2>/dev/null || true

# Available RAM (MemAvailable) in GiB
mem_avail_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo "")
if [[ -n "$mem_avail_kb" ]]; then
  mem_avail_gb=$(( mem_avail_kb / 1024 / 1024 ))
else
  mem_avail_gb=$(free -g 2>/dev/null | awk '/^Mem:/ {print $7}' || echo 0)
fi

# Threads for sort (max 32, min 4)
sort_threads="$threads"
if (( sort_threads > 32 )); then sort_threads=32; fi
if (( sort_threads < 4 )); then sort_threads=4; fi

# Memory per thread for sort:
# uses ~70% of MemAvailable split between sort_threads, min 1G, max 4G per thread
if (( mem_avail_gb <= 0 )); then
  sort_mem="2G"
else
  total_for_sort=$(( mem_avail_gb * 70 / 100 ))
  per_thread=$(( total_for_sort / sort_threads ))
  if (( per_thread < 1 )); then per_thread=1; fi
  if (( per_thread > 4 )); then per_thread=4; fi
  sort_mem="${per_thread}G"
fi

echo "Samtools sort settings:"
echo "  sort_threads=${sort_threads}"
echo "  sort_mem=${sort_mem}"
echo "  tmp_dir=${tmp_dir}"
echo "  ulimit -n=$(ulimit -n 2>/dev/null || echo 'NA')"

echo "Starting mapping + sorting (Intermediate BAM for maximum stability)..."

# --------------------------------------------------------------
# More stable strategy on HPC: Intermediate BAM + sort
#   (reduces pressure on temporaries and facilitates retries)
# --------------------------------------------------------------
unsorted_bam="${output_dir}/${sample}.bam"

# 1) Mapping -> Unsorted BAM
bowtie2 --rg-id "${sample}" --rg "${read_group}" --rg PL:ILLUMINA \
  -I "${i}" -X "${x}" -p "${threads}" -k 3 -t \
  -x "${INDEXES}" -1 "${f1}" -2 "${f2}" 2> "${log_bt2}" \
| samtools view -bhS -o "${unsorted_bam}" -

# 2) Sort BAM (controlling memory, tmp, and threads)
samtools sort \
  -@ "${sort_threads}" \
  -m "${sort_mem}" \
  -T "${tmp_dir}/${sample}.tmp" \
  -o "${sorted_bam}" \
  "${unsorted_bam}"

# 3) Clean intermediate BAM (optional, comment to keep it)
rm -f "${unsorted_bam}"

echo "Mapping and sorting completed. BAM: $sorted_bam"

# --------------------------------------------------------------
# BAM Validation
# --------------------------------------------------------------
samtools flagstat "${sorted_bam}" > "${output_dir}/${sample}_sorted_flagstat.log"

if grep -q "in total" "${output_dir}/${sample}_sorted_flagstat.log"; then
  echo "Valid sorted BAM file: ${sorted_bam}"
else
  echo "WARNING: BAM possibly empty or corrupted. Check: ${output_dir}/${sample}_sorted_flagstat.log"
  exit 5
fi

echo "Process completed successfully for sample ${sample}."