#!/bin/bash

# ------------------------------------------------------------------
# Script: mapping_paired_metagenomics.sh
# Description:
#   Maps paired-end reads against a host genome.
#   Outputs:
#     1) Full sorted BAM
#     2) BAM of primary perfect host alignments
#        - 100% identity: NM:i:0
#        - 100% read coverage: CIGAR = read_length + "M"
#     3) FASTQ reads that do NOT meet the perfect criteria (non-host reads)
#
# Usage:
#   ./mapping_paired_metagenomics.sh <R1.fastq.gz> <R2.fastq.gz> <reference> \
#       <workdir> <threads> [I=200] [X=400] [sample_name]
# ------------------------------------------------------------------

set -euo pipefail

if [ $# -lt 5 ]; then
  echo "USAGE: $0 <R1.fastq.gz> <R2.fastq.gz> <reference> <workdir> <threads> [I=200] [X=400] [sample_name]"
  exit 1
fi

f1="$1"
f2="$2"
reference="$3"
workdir="$4"
threads="$5"
i="${6:-200}"
x="${7:-400}"
sample_name="${8:-}"

if [ ! -f "$f1" ]; then
  echo "ERROR: R1 file not found: $f1"
  exit 2
fi
if [ ! -f "$f2" ]; then
  echo "ERROR: R2 file not found: $f2"
  exit 2
fi
if [ ! -f "$reference" ]; then
  echo "ERROR: Reference file not found: $reference"
  exit 2
fi

# Derive sample name from R1 if not provided
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

# Build Bowtie2 index prefix
ref_dir="$(dirname "$reference")"
ref_base="$(basename "$reference")"
ref_base="${ref_base%.gz}"
ref_base="${ref_base%.fasta}"
ref_base="${ref_base%.fa}"
ref_base="${ref_base%.fna}"
INDEXES="${ref_dir}/${ref_base}"

# Output paths
output_dir="${workdir}/${sample_name}_${ref_base}"
mkdir -p "$output_dir"

sorted_bam="${output_dir}/${sample_name}_sorted.bam"
perfect_bam="${output_dir}/${sample_name}_perfect_primary.bam"
nonperfect_names="${output_dir}/${sample_name}_nonperfect_readnames.txt"
nonperfect_r1="${output_dir}/${sample_name}_nonperfect_R1.fastq.gz"
nonperfect_r2="${output_dir}/${sample_name}_nonperfect_R2.fastq.gz"
log_bt2="${output_dir}/${sample_name}_bowtie2.log"

if [ ! -f "${INDEXES}.1.bt2" ] && [ ! -f "${INDEXES}.1.bt2l" ]; then
  echo "ERROR: Bowtie2 index not found: ${INDEXES}"
  echo "Generate with: bowtie2-build ${reference} ${INDEXES}"
  exit 3
fi

echo "Working directory: $output_dir"
echo "Sample: $sample_name"
echo "Bowtie2 index: $INDEXES"
echo "Reads: R1=$f1  R2=$f2"

# Samtools sort settings
tmp_root="${TMPDIR:-${output_dir}/tmp}"
tmp_dir="${tmp_root}/${sample_name}_samtools_tmp"
mkdir -p "$tmp_dir"
ulimit -n 65535 2>/dev/null || true

mem_avail_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo "")
if [[ -n "$mem_avail_kb" ]]; then
  mem_avail_gb=$(( mem_avail_kb / 1024 / 1024 ))
else
  mem_avail_gb=$(free -g 2>/dev/null | awk '/^Mem:/ {print $7}' || echo 0)
fi

sort_threads="$threads"
if (( sort_threads > 32 )); then sort_threads=32; fi
if (( sort_threads < 4 ));  then sort_threads=4;  fi

if (( mem_avail_gb <= 0 )); then
  sort_mem="2G"
else
  per_thread=$(( mem_avail_gb * 70 / 100 / sort_threads ))
  per_thread=$(( per_thread < 1 ? 1 : per_thread > 4 ? 4 : per_thread ))
  sort_mem="${per_thread}G"
fi

echo "Samtools sort settings: threads=$sort_threads  mem=$sort_mem"

unsorted_bam="${output_dir}/${sample_name}.bam"

# 1) Strict end-to-end mapping (no secondary reads from -k)
echo "Step 1: Mapping..."
bowtie2 \
  --rg-id "${sample_name}" --rg "${read_group}" --rg PL:ILLUMINA \
  --end-to-end --very-sensitive \
  -I "${i}" -X "${x}" -p "${threads}" -t \
  -x "${INDEXES}" -1 "${f1}" -2 "${f2}" \
  2> "${log_bt2}" \
| samtools view -bhS -o "${unsorted_bam}" -

samtools sort -@ "${sort_threads}" -m "${sort_mem}" \
  -T "${tmp_dir}/${sample_name}.tmp" -o "${sorted_bam}" "${unsorted_bam}"
rm -f "${unsorted_bam}"
samtools index -@ "${sort_threads}" "${sorted_bam}"

# 2) Extract perfect primary host alignments (MAPQ>=0, no secondary/supplementary, NM:i:0, full CIGAR)
echo "Step 2: Extracting perfect primary alignments..."
samtools view -h -F 2304 "${sorted_bam}" | \
awk 'BEGIN{OFS="\t"}
/^@/ {print; next}
{
  seq_len=length($10)
  if ($6 == seq_len "M" && $0 ~ /NM:i:0(\t|$)/) print
}' | \
samtools view -b -o "${perfect_bam}" -

samtools index -@ "${sort_threads}" "${perfect_bam}"

# 3) Get perfect read names
echo "Step 3: Extracting perfect read names..."
samtools view "${perfect_bam}" | cut -f1 | sort -u > "${output_dir}/${sample_name}_perfect_readnames.txt"

# 4) Get all read names and find non-perfect ones
echo "Step 4: Finding non-host reads..."
zcat "$f1" | sed -n '1~4s/^@//p' | sed 's/[[:space:]].*$//' | sort -u > "${output_dir}/${sample_name}_all_readnames.txt"

comm -23 \
  "${output_dir}/${sample_name}_all_readnames.txt" \
  "${output_dir}/${sample_name}_perfect_readnames.txt" \
> "${nonperfect_names}"

# 5) Extract non-host FASTQ using seqtk
echo "Step 5: Extracting non-host FASTQ reads..."
if ! command -v seqtk >/dev/null 2>&1; then
  echo "ERROR: seqtk is not installed or not in PATH."
  echo "Install seqtk and rerun the FASTQ extraction step."
  exit 4
fi

seqtk subseq "$f1" "${nonperfect_names}" | gzip > "${nonperfect_r1}"
seqtk subseq "$f2" "${nonperfect_names}" | gzip > "${nonperfect_r2}"

# 6) Stats report
echo "Step 6: Generating stats..."
samtools flagstat "${sorted_bam}"   > "${output_dir}/${sample_name}_sorted_flagstat.log"
samtools flagstat "${perfect_bam}"  > "${output_dir}/${sample_name}_perfect_primary_flagstat.log"

total_primary=$(samtools view -c -F 2304 "${sorted_bam}")
perfect_count=$(samtools view -c "${perfect_bam}")
nonperfect_count=$(wc -l < "${nonperfect_names}")

{
  printf "sample\tprimary_total\tperfect_primary\tpercent_perfect\tnonperfect_reads\n"
  if [ "${total_primary}" -gt 0 ]; then
    pct=$(awk -v a="$perfect_count" -v b="$total_primary" 'BEGIN{printf "%.4f", (a*100)/b}')
  else
    pct="0.0000"
  fi
  printf "%s\t%s\t%s\t%s\t%s\n" "$sample_name" "$total_primary" "$perfect_count" "$pct" "$nonperfect_count"
} > "${output_dir}/${sample_name}_perfect_primary_summary.tsv"

echo ""
echo "Results:"
echo "  Full sorted BAM:           ${sorted_bam}"
echo "  Perfect primary BAM:       ${perfect_bam}"
echo "  Non-host reads R1:         ${nonperfect_r1}"
echo "  Non-host reads R2:         ${nonperfect_r2}"
echo "  Summary TSV:               ${output_dir}/${sample_name}_perfect_primary_summary.tsv"
echo "Process completed successfully for sample ${sample_name}."