#!/bin/bash
set -euo pipefail

# --------------------------------------------------------------
# Description:
# Maps individual reads to a reference using Bowtie2
# and generates a sorted BAM file.
#
# Options:
#   --multimap K   -> bowtie2 -k K  (multi-mapping; defaults to K=3)
#   --unique       -> filters and keeps ONLY "reliable" alignments
#                    (MAPQ >= N and no secondary/supplementary)
#   --mapq N       -> MAPQ threshold for --unique (defaults to 20)
#
# If NO options are passed, the script works as before: -k 3.
# --------------------------------------------------------------

usage() {
  cat <<EOF
Usage:
  $0 <sample_id> <reference.fasta> <work_dir> <threads> [--multimap K] [--unique] [--mapq N]
EOF
}

if [ $# -lt 4 ]; then
  usage
  exit 1
fi

# Required arguments
sample=$1
ref_fasta=$2
work_dir=$3
threads=$4
shift 4

# Optional arguments (defaults)
MULTIMAP_K=3
UNIQUE_MODE=0
UNIQUE_MAPQ=20

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --multimap)
      [ $# -ge 2 ] || { echo "ERROR: --multimap requires K"; exit 1; }
      MULTIMAP_K="$2"
      shift 2
      ;;
    --unique)
      UNIQUE_MODE=1
      shift 1
      ;;
    --mapq)
      [ $# -ge 2 ] || { echo "ERROR: --mapq requires N"; exit 1; }
      UNIQUE_MAPQ="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

# Validations
if ! [[ "$MULTIMAP_K" =~ ^[0-9]+$ ]] || [ "$MULTIMAP_K" -lt 1 ]; then
  echo "ERROR: --multimap K must be an integer >= 1. Received: $MULTIMAP_K"
  exit 1
fi

if ! [[ "$UNIQUE_MAPQ" =~ ^[0-9]+$ ]] || [ "$UNIQUE_MAPQ" -lt 0 ]; then
  echo "ERROR: --mapq N must be an integer >= 0. Received: $UNIQUE_MAPQ"
  exit 1
fi

if [ "$UNIQUE_MODE" -eq 1 ] && [ "$MULTIMAP_K" -ne 3 ]; then
  echo "ERROR: --unique and --multimap should not be used together."
  exit 1
fi

# Read Group
read_group="SM:${sample}"

# Input FASTQ
input_fastq="/biodata1/HTS/GBS/demultiplexed_data/reads/${sample}_corrected.fastq.gz"

# Reference Index
ref_dir=$(dirname "$ref_fasta")
ref_name=$(basename "$ref_fasta" .fasta)
INDEXES="${ref_dir}/${ref_name}"

# Output within the user-specified folder, in 'gbs' subfolder
output_dir="${work_dir}/gbs/${ref_name}"
output_bam="${output_dir}/${sample}_bowtie2_sorted.bam"

# Initial validations
if [ ! -f "$INDEXES.1.bt2" ] && [ ! -f "$INDEXES.1.bt2l" ]; then
  echo "ERROR: Bowtie2 index not found: ${INDEXES}.1.bt2 or ${INDEXES}.1.bt2l"
  exit 1
fi

if [ ! -f "$input_fastq" ]; then
  echo "ERROR: FASTQ not found: $input_fastq"
  exit 2
fi

mkdir -p "$output_dir"
echo "Output directory: $output_dir"

if [ -f "$output_bam" ]; then
  echo "Final BAM already exists: $output_bam"
  echo "Skipping."
  exit 0
fi

log_bowtie="${output_dir}/${sample}_bowtie2.log"
tmp_bam="${output_dir}/${sample}_bowtie2.tmp.bam"

echo "Mapping in progress for ${sample}..."

if [ "$UNIQUE_MODE" -eq 1 ]; then
  echo "Mode: UNIQUE (MAPQ filter >= ${UNIQUE_MAPQ}, no secondary/supplementary)"
  bowtie2 \
    -x "$INDEXES" \
    -U "$input_fastq" \
    --rg-id "$sample" \
    --rg "$read_group" \
    --rg PL:ILLUMINA \
    -p "$threads" \
    -k 1 \
    -t \
    2> "$log_bowtie" \
    | samtools view -bh -q "$UNIQUE_MAPQ" -F 2304 - \
    > "$tmp_bam"
else
  echo "Mode: MULTIMAP (bowtie2 -k ${MULTIMAP_K})"
  bowtie2 \
    -x "$INDEXES" \
    -U "$input_fastq" \
    --rg-id "$sample" \
    --rg "$read_group" \
    --rg PL:ILLUMINA \
    -p "$threads" \
    -k "$MULTIMAP_K" \
    -t \
    2> "$log_bowtie" \
    | samtools view -bh - \
    > "$tmp_bam"
fi

echo "Sorting BAM..."
samtools sort "$tmp_bam" -o "$output_bam"
samtools index "$output_bam"

echo "QC (flagstat)..."
samtools flagstat "$output_bam" > "${output_dir}/${sample}_bowtie2_flagstat.log"

rm -f "$tmp_bam"
echo "Done: $output_bam"