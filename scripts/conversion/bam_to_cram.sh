#!/bin/bash

#######################################################################
# Script: bam_to_cram.sh
# Description: Converts a BAM file to a CRAM file using samtools.
#
# Usage:
#   ./bam_to_cram.sh -i <input.bam> \
#                    -r <reference.fasta> \
#                    -t <num_threads> \
#                    -d <output_directory>
#
# Parameters:
#   -i    Path to input BAM file
#   -r    Path to reference FASTA file
#   -t    Number of threads to use
#   -d    Output directory for the CRAM file
#   -h    Show help message
#######################################################################

# Show help message
show_help() {
  cat << EOF
Usage: $0 -i <input.bam> -r <reference.fasta> -t <threads> -d <output_directory>

Options:
  -i    Input BAM file
  -r    Reference FASTA file
  -t    Number of threads
  -d    Output directory
  -h    Show this help message
EOF
  exit 0
}

# Parse arguments using POSIX-compliant getopts
while getopts ":i:r:t:d:h" opt; do
  case $opt in
    i) BAM_PATH="$OPTARG" ;;
    r) REF_PATH="$OPTARG" ;;
    t) NUM_THREADS="$OPTARG" ;;
    d) OUT_DIR="$OPTARG" ;;
    h) show_help ;;
    \?) echo "Error: Invalid option -$OPTARG" >&2; show_help ;;
    :) echo "Error: Option -$OPTARG requires an argument." >&2; show_help ;;
  esac
done

# Validate required parameters
[ -z "$BAM_PATH" ] && echo "Error: missing -i <input.bam>" && show_help
[ -z "$REF_PATH" ] && echo "Error: missing -r <reference.fasta>" && show_help
[ -z "$NUM_THREADS" ] && echo "Error: missing -t <threads>" && show_help
[ -z "$OUT_DIR" ] && echo "Error: missing -d <output_directory>" && show_help

# Check file existence
if [ ! -f "$BAM_PATH" ]; then
  echo "Error: BAM file not found: $BAM_PATH"
  exit 1
fi

if [ ! -f "$REF_PATH" ]; then
  echo "Error: Reference file not found: $REF_PATH"
  exit 1
fi

if ! [[ "$NUM_THREADS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: Number of threads must be a positive integer"
  exit 1
fi

# Create output directory if it doesn't exist
if [ ! -d "$OUT_DIR" ]; then
  echo "Creating output directory: $OUT_DIR"
  mkdir -p "$OUT_DIR"
fi

# Generate .fai index if not present
if [ ! -f "${REF_PATH}.fai" ]; then
  echo "Generating .fai index for reference..."
  samtools faidx "$REF_PATH"
fi

# Generate output CRAM file name
BAM_BASE=$(basename "$BAM_PATH" .bam)
CRAM_PATH="${OUT_DIR}/${BAM_BASE}.cram"

# Skip if CRAM already exists
if [ -f "$CRAM_PATH" ]; then
  echo "CRAM file already exists: $CRAM_PATH. Skipping conversion."
  exit 0
fi

# Convert BAM to CRAM
echo "Converting $BAM_PATH to $CRAM_PATH using $NUM_THREADS threads..."
samtools view -@ "$NUM_THREADS" -C -T "$REF_PATH" -o "$CRAM_PATH" "$BAM_PATH"

# Check result
if [ $? -eq 0 ]; then
  echo "CRAM file successfully created: $CRAM_PATH"
else
  echo "Error: Conversion failed."
  exit 1
fi

