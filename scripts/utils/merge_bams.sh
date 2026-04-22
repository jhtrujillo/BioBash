#!/bin/bash

###############################################################################
# Script: merge_bams.sh
# Description: Merge multiple BAM files using samtools.
#
# Usage:
#   ./merge_bams.sh -o <output_path.bam> -p <threads> <bam1> <bam2> [...bamN]
#
# Example:
#   ./merge_bams.sh -o /ruta/salida/resultado.bam -p 4 *.bam
#
# Parameters:
#   -o   Full path to the output BAM file (e.g., /ruta/salida/merged.bam)
#   -p   Number of threads to use with samtools
#   <bam1> <bam2> [...bamN]  List of BAM files to merge (minimum 2)
###############################################################################

# Initialize variables
output_bam=""
threads=1

# Parse command-line arguments
while getopts "o:p:" opt; do
  case $opt in
    o) output_bam="$OPTARG" ;;
    p) threads="$OPTARG" ;;
    *)
      echo "Usage: $0 -o <output_path.bam> -p <threads> <bam1> <bam2> [...bamN]"
      exit 1
      ;;
  esac
done

shift $((OPTIND -1))  # Remove parsed options from argument list

# Input validation
if [[ -z "$output_bam" || "$#" -lt 2 ]]; then
  echo "Usage: $0 -o <output_path.bam> -p <threads> <bam1> <bam2> [...bamN]"
  echo "Error: You must provide output path (-o), number of threads (-p), and at least two BAM files."
  exit 1
fi

bam_files=("$@")

# Check that input BAM files exist
for bam in "${bam_files[@]}"; do
  if [ ! -f "$bam" ]; then
    echo "Error: BAM file not found: $bam"
    exit 2
  fi
done

# Create output directory if it doesn't exist
output_dir=$(dirname "$output_bam")
mkdir -p "$output_dir"

# Merge BAMs if output doesn't already exist
if [ ! -f "$output_bam" ]; then
  echo "Merging BAM files..."
  samtools merge -@ "$threads" "$output_bam" "${bam_files[@]}"
else
  echo "Output file already exists: $output_bam"
fi

# Report output size
echo "Generated BAM file:"
du -sh "$output_bam"
