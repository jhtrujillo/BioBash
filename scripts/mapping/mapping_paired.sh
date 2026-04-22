#!/bin/bash
# --------------------------------------------------------------
# Script to map paired-end reads using Bowtie2 + Samtools
# Robust for HPC: controls memory/tmp for samtools sort
# --------------------------------------------------------------
# Usage:
# ./mapping_paired.sh <R1.fastq.gz> <R2.fastq.gz> <reference> <workdir> <threads> [I=200] [X=400] [sample_name]
#
# Example:
# ./mapping_paired.sh sample_R1.fastq.gz sample_R2.fastq.gz /path/ref.fasta /path/results 32
#
# Parameters:
#   R1.fastq.gz   : forward reads file
#   R2.fastq.gz   : reverse reads file
#   reference     : reference genome in FASTA format
#   workdir       : output directory
#   threads       : number of threads for Bowtie2
#   I             : minimum insert size (optional, default=200)
#   X             : maximum insert size (optional, default=400)
#   sample_name   : sample name for read group (optional)
# --------------------------------------------------------------

set -euo pipefail

# --------------------------------------------------------------
# Validate minimum number of arguments
# --------------------------------------------------------------
if [ $# -lt 5 ]; then
  echo "USAGE: $0 <R1.fastq.gz> <R2.fastq.gz> <reference> <workdir> <threads> [I=200] [X=400] [sample_name]"
  exit 1
fi

# --------------------------------------------------------------
# Inputs and parameters
# --------------------------------------------------------------
f1="$1"
f2="$2"
reference="$3"
workdir="$4"
threads="$5"
i="${6:-200}"
x="${7:-400}"
sample_name="${8:-}"

# --------------------------------------------------------------
# Verify input files
# --------------------------------------------------------------
if [ ! -f "$f1" ]; then
  echo "ERROR: R1 file does not exist: $f1"
  exit 2
fi

if [ ! -f "$f2" ]; then
  echo "ERROR: R2 file does not exist: $f2"
  exit 2
fi

if [ ! -f "$reference" ]; then
  echo "ERROR: Reference does not exist: $reference"
  exit 2
fi

# --------------------------------------------------------------
# Derive sample name if not provided
# --------------------------------------------------------------
if [ -z "$sample_name" ]; then
  sample_name="$(basename "$f1")"
  sample_name="${sample_name%.fastq.gz}"
  sample_name="${sample_name%.fq.gz}"
  sample_name="${sample_name%.fastq}"
  sample_name="${sample_name%.fq}"
  sample_name="${sample_name%_R1}"
  sample_name="${sample_name%_1}"
fi

read_group="SM:${sample_name}"

# --------------------------------------------------------------
# Build index prefix robustly
# --------------------------------------------------------------
directory="$(dirname "$reference")"
ref_prefix="$(basename "$reference")"
ref_prefix="${ref_prefix%.gz}"
ref_prefix="${ref_prefix%.fasta}"
ref_prefix="${ref_prefix%.fa}"
ref_prefix="${ref_prefix%.fna}"
INDEXES="${directory}/${ref_prefix}"

# --------------------------------------------------------------
# Prepare output
# --------------------------------------------------------------
output_dir="${workdir}/${sample_name}_${ref_prefix}"
mkdir -p "$output_dir"

sorted_bam="${output_dir}/${sample_name}_sorted.bam"
log_bt2="${output_dir}/${sample_name}_bowtie2.log"

# --------------------------------------------------------------
# Validate indexes (.bt2 or .bt2l)
# --------------------------------------------------------------
if [ ! -f "${INDEXES}.1.bt2" ] && [ ! -f "${INDEXES}.1.bt2l" ]; then
  echo "ERROR: Bowtie2 index not found with prefix:"
  echo "  ${INDEXES}"
  echo "Expected to find:"
  echo "  ${INDEXES}.1.bt2  or  ${INDEXES}.1.bt2l"
  echo ""
  echo "Generate the index with:"
  echo "  bowtie2-build ${reference} ${INDEXES}"
  exit 3
fi

# --------------------------------------------------------------
# Skip processing if sorted BAM already exists
# --------------------------------------------------------------
if [ -f "$sorted_bam" ]; then
  echo "Sorted BAM file already exists: $sorted_bam"
  echo "Skipping process for ${sample_name}."
  exit 0
fi

echo "Working directory: $output_dir"
echo "Sample: $sample_name"
echo "Bowtie2 index (prefix): $INDEXES"
echo "Reads:"
echo "  R1: $f1"
echo "  R2: $f2"

# --------------------------------------------------------------
# Robust settings for samtools sort
# --------------------------------------------------------------
tmp_root="${TMPDIR:-${output_dir}/tmp}"
tmp_dir="${tmp_root}/${sample_name}_samtools_tmp"
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

# Memory per thread for sort
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
# Stable strategy: Intermediate BAM + sort
# --------------------------------------------------------------
unsorted_bam="${output_dir}/${sample_name}.bam"

# 1) Mapping -> Unsorted BAM
bowtie2 \
  --rg-id "${sample_name}" \
  --rg "${read_group}" \
  --rg PL:ILLUMINA \
  -I "${i}" \
  -X "${x}" \
  -p "${threads}" \
  -k 3 \
  -t \
  -x "${INDEXES}" \
  -1 "${f1}" \
  -2 "${f2}" \
  2> "${log_bt2}" \
| samtools view -bhS -o "${unsorted_bam}" -

# 2) Sort BAM
samtools sort \
  -@ "${sort_threads}" \
  -m "${sort_mem}" \
  -T "${tmp_dir}/${sample_name}.tmp" \
  -o "${sorted_bam}" \
  "${unsorted_bam}"

# 3) Clean intermediate BAM
rm -f "${unsorted_bam}"

echo "Mapping and sorting completed. BAM: $sorted_bam"

# --------------------------------------------------------------
# Index BAM
# --------------------------------------------------------------
samtools index -@ "${sort_threads}" "${sorted_bam}"

# --------------------------------------------------------------
# BAM Validation
# --------------------------------------------------------------
samtools flagstat "${sorted_bam}" > "${output_dir}/${sample_name}_sorted_flagstat.log"

if grep -q "in total" "${output_dir}/${sample_name}_sorted_flagstat.log"; then
  echo "Valid sorted BAM file: ${sorted_bam}"
else
  echo "WARNING: BAM possibly empty or corrupted. Check: ${output_dir}/${sample_name}_sorted_flagstat.log"
  exit 5
fi

echo "Process completed successfully for sample ${sample_name}."
