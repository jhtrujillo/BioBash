#!/bin/bash

# --------------------------------------------------------------
# Script: multisample_variant_detector_by_chr.sh
# Author: Jhon Henry Trujillo Montenegro
# Date: April 22, 2025
# Description:
#    This script efficiently extracts reads for a specific chromosome
#    from multiple BAM or CRAM files located in a user-defined input
#    directory. It uses the 'find' command to locate these files and a
#    loop to process them sequentially. It calls the 'extract_chromosome_from_bam.sh'
#    utility to perform extraction on each input file. The resulting
#    chromosome-specific files are saved in a temporary subdirectory.
#    Optionally, it can execute the multisample variant caller and then
#    clean up the temporary files.
#
# Usage:
#    ./multisample_variant_detector_by_chr.sh -d <input_dir> -c <chromosome> [-p <threads>] [-r <ref.fasta>] [-o <output.vcf>] [-t <temp_dir>]
#
# Example:
#    ./multisample_variant_detector_by_chr.sh -d all_bams -c chr2 -p 16 -r /path/to/ref.fasta -o variants/output_chr2.vcf
# --------------------------------------------------------------

set -euo pipefail

# --------------------------------------------------------------
# Load configuration if available
# --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_BASE="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ -f "$SUITE_BASE/lib/load_config.sh" ]]; then
    source "$SUITE_BASE/lib/load_config.sh"
fi

# --------------------------------------------------------------
# Parse options
# --------------------------------------------------------------
while getopts "d:c:p:r:o:t:" opt; do
  case "$opt" in
    d) input_dir="$OPTARG" ;;
    c) chromosome="$OPTARG" ;;
    p) threads="$OPTARG" ;;
    r) ref_fasta="$OPTARG" ;;
    o) output_vcf="$OPTARG" ;;
    t) temp_dir="$OPTARG" ;;
    *) echo "Usage: $0 -d <input_dir> -c <chromosome> [-p <threads>] [-r <ref.fasta>] [-o <output.vcf>] [-t <temp_dir>]" >&2; exit 1 ;;
  esac
done

# Verify mandatory arguments
if [ -z "${input_dir:-}" ] || [ -z "${chromosome:-}" ]; then
  echo "Error: The -d (input directory) and -c (chromosome) arguments are mandatory." >&2
  exit 1
fi

# Skip if output already exists
if [ -n "${output_vcf:-}" ] && [ -f "$output_vcf" ]; then
  echo "Warning: Output VCF file '$output_vcf' already exists. Skipping."
  exit 0
fi

# Defaults
threads="${threads:-20}"

if [ -z "${temp_dir:-}" ]; then
  temp_dir="$input_dir/${chromosome}_extracted_temp"
else
  temp_dir="${temp_dir%/}/${chromosome}_temp"
fi

mkdir -p "$temp_dir"

# --------------------------------------------------------------
# Find BAM/CRAM files and extract chromosome
# --------------------------------------------------------------
# We find the extractor script relative to this script's directory
EXTRACTOR_SCRIPT="$SUITE_BASE/scripts/utils/extract_chromosome_from_bam.sh"
VARIANT_SCRIPT="$SUITE_BASE/scripts/variants/multisample_variant_detector.sh"

find "$input_dir" -maxdepth 1 -type f \( -name "*.bam" -o -name "*.cram" \) | while IFS= read -r bam_file; do
  echo "Extracting chromosome $chromosome from file: $bam_file"
  bash "$EXTRACTOR_SCRIPT" -b "$bam_file" -c "$chromosome" -o "$temp_dir" -p "$threads"
done

echo "Extraction completed. Files saved in: $temp_dir"

# --------------------------------------------------------------
# Execute variant detector if requested
# --------------------------------------------------------------
if [ -n "${ref_fasta:-}" ] && [ -n "${output_vcf:-}" ]; then
  echo "Running multisample variant detector..."
  time bash "$VARIANT_SCRIPT" -d "$temp_dir" -r "$ref_fasta" -o "$output_vcf"
  echo "Variant analysis completed: $output_vcf"
elif [ -n "${ref_fasta:-}" ] || [ -n "${output_vcf:-}" ]; then
  echo "Warning: Both -r (reference) and -o (output VCF) are required for variant analysis."
fi

# Cleanup
if [ -d "$temp_dir" ]; then
  echo "Cleaning up temporary directory: $temp_dir"
  rm -rf "$temp_dir"
fi

exit 0
