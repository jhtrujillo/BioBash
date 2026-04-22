#!/bin/bash
# --------------------------------------------------------------
# Script to map paired-end reads using Bowtie2 + Samtools
# --------------------------------------------------------------
# Usage: ./mapping_pe.sh <sample_id> <reference> <workdir> <threads> [I=200] [X=400]
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
# Input read paths (Assuming standard paths for this environment)
# --------------------------------------------------------------
f1="/biodata2/HTS/WGS/${sample}/${sample}_R1.fastq.gz"
f2="/biodata2/HTS/WGS/${sample}/${sample}_R2.fastq.gz"

if [ ! -f "$f1" ]; then
  echo "ERROR: R1 file not found: $f1"
  exit 4
fi

# --------------------------------------------------------------
# Prepare output
# --------------------------------------------------------------
output_dir="${workdir}/${sample}"
mkdir -p "$output_dir"
output_bam="${output_dir}/${sample}_sorted.bam"

echo "Mapping reads for ${sample}..."
bowtie2 \
  --rg-id "${sample}" --rg "${read_group}" --rg PL:ILLUMINA \
  -I "${i}" -X "${x}" -p "${threads}" -t \
  -x "${INDEXES}" -1 "${f1}" -2 "${f2}" \
| samtools sort -@ "$threads" -o "$output_bam" -

samtools index "$output_bam"

echo "Mapping completed: $output_bam"
