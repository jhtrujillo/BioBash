#!/bin/bash

# --------------------------------------------------------------
# Script: generate_subbam_from_bam.sh
# Author: Jhon Henry Trujillo Montenegro
# Description:
#   Extracts reads for a specific chromosome from multiple BAM/CRAM
#   files in an input directory, sequentially.
#   Uses extract_chromosome_from_bam.sh internally.
#
# Usage:
#   ./generate_subbam_from_bam.sh -d <input_dir> -c <chromosome> [-p <threads>]
#
# Example:
#   ./generate_subbam_from_bam.sh -d all_bams -c chr2 -p 16
# --------------------------------------------------------------

# Load config if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_BASE="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ -f "$SUITE_BASE/lib/load_config.sh" ]]; then
    source "$SUITE_BASE/lib/load_config.sh"
fi

EXTRACTOR_SCRIPT="$SUITE_BASE/scripts/utils/extract_chromosome_from_bam.sh"

while getopts "d:c:p:" opt; do
  case "$opt" in
    d) input_dir="$OPTARG"  ;;
    c) chromosome="$OPTARG" ;;
    p) threads="$OPTARG"    ;;
    *) echo "Usage: $0 -d <input_dir> -c <chromosome> [-p <threads>]" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ -z "${input_dir:-}" ] || [ -z "${chromosome:-}" ]; then
  echo "Error: -d (input directory) and -c (chromosome) are required." >&2
  exit 1
fi

threads="${threads:-20}"
temp_dir="${input_dir}/${chromosome}_temp"
mkdir -p "$temp_dir"

echo "Extracting chromosome $chromosome from all BAM/CRAM files in: $input_dir"
echo "Temporary directory: $temp_dir"

for bam_file in $(find "$input_dir" -maxdepth 1 -type f \( -name "*.bam" -o -name "*.cram" \)); do
  echo "Processing: $bam_file"
  bash "$EXTRACTOR_SCRIPT" -b "$bam_file" -c "$chromosome" -o "$temp_dir" -p "$threads"
done

echo "Extraction completed. Files saved in: $temp_dir"
exit 0
