#!/bin/bash
# --------------------------------------------------------------
# Script to map paired-end reads using Bowtie2 + Samtools (RADseq)
# --------------------------------------------------------------
# Usage: ./mapping_radseq.sh <sample_id> <reference> <workdir> <threads> [I=200] [X=400]

set -euo pipefail

# --------------------------------------------------------------
# Validate minimum number of arguments
# --------------------------------------------------------------
if [ $# -lt 4 ]; then
    echo "USAGE: $0 <sample_id> <reference> <workdir> <threads> [I=200] [X=400]"
    exit 1
fi

# --------------------------------------------------------------
# Command line inputs
# --------------------------------------------------------------
sample="$1"
reference="$2"
workdir="$3"
threads="$4"
i="${5:-200}"
x="${6:-400}"
read_group="SM:${sample}"

# --------------------------------------------------------------
# Verify reference
# --------------------------------------------------------------
if [ ! -f "$reference" ]; then
  echo "ERROR: Reference does not exist: $reference"
  exit 2
fi

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
# Verify Bowtie2 indexes (.bt2 or .bt2l)
# --------------------------------------------------------------
if [ ! -f "${INDEXES}.1.bt2" ] && [ ! -f "${INDEXES}.1.bt2l" ]; then
  echo "ERROR: Bowtie2 index not found for prefix: ${INDEXES}"
  exit 3
fi

# --------------------------------------------------------------
# Input read paths
# --------------------------------------------------------------
f1="/biodata1/HTS/RAD-demultiplexed/${sample}_R1.fastq.gz"
f2="/biodata1/HTS/RAD-demultiplexed/${sample}_R2.fastq.gz"

if [ ! -f "$f1" ] || [ ! -f "$f2" ]; then
  echo "ERROR: FASTQ files not found for ${sample}"
  exit 4
fi

# --------------------------------------------------------------
# Prepare output
# --------------------------------------------------------------
output_dir="${workdir}/${sample}"
mkdir -p "$output_dir"
output_bam="${output_dir}/${sample}_rad_sorted.bam"

echo "Mapping RADseq reads for ${sample}..."
bowtie2 \
  --rg-id "${sample}" --rg "${read_group}" --rg PL:ILLUMINA \
  -I "${i}" -X "${x}" -p "${threads}" -t \
  -x "${INDEXES}" -1 "${f1}" -2 "${f2}" \
| samtools sort -@ "$threads" -o "$output_bam" -

samtools index "$output_bam"

echo "RADseq mapping completed: $output_bam"
