#!/bin/bash

# Update the by_chr_v2 script to use suite paths instead of hardcoded paths

set -euo pipefail

# -----------------------------------------------
# Load configuration if available
# -----------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_BASE="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ -f "$SUITE_BASE/lib/load_config.sh" ]]; then
    source "$SUITE_BASE/lib/load_config.sh"
fi

EXTRACTOR_SCRIPT="$SUITE_BASE/scripts/utils/extract_chromosome_from_bam.sh"
VARIANT_SCRIPT="$SUITE_BASE/scripts/variants/multisample_variant_detector.sh"

# --- Display help ---
show_help() {
    echo "Usage: $0 -d <input_dir> -c <chr> -p <threads> [--ploidy <ploidy>] -r <ref.fasta> -o <output.vcf> [-t <tmp_dir>]"
    echo ""
    echo "  -d          Input directory with BAM/CRAM files (required)."
    echo "  -c          Chromosome to extract (e.g., 'chr1', '2') (required)."
    echo "  -p          Number of threads. Default: 20."
    echo "  --ploidy    Ploidy level for variant calling. Default: 10."
    echo "  -r          Reference genome FASTA. Required for variant calling."
    echo "  -o          Output VCF file. Required for variant calling."
    echo "  -t          Base path for the temporary directory."
    echo "  -h, --help  Show this help message."
}

# --- Defaults ---
input_dir=""
chromosome=""
threads=20
ploidy=10
ref_fasta=""
output_vcf=""
temp_dir=""

# --- Parse arguments ---
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -d)        input_dir="$2";   shift 2 ;;
        -c)        chromosome="$2";  shift 2 ;;
        -p)        threads="$2";     shift 2 ;;
        --ploidy)  ploidy="$2";      shift 2 ;;
        -r)        ref_fasta="$2";   shift 2 ;;
        -o)        output_vcf="$2";  shift 2 ;;
        -t)        temp_dir="$2";    shift 2 ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Error: Unknown parameter: $1"; show_help >&2; exit 1 ;;
    esac
done

# Mandatory arguments
if [ -z "$input_dir" ] || [ -z "$chromosome" ]; then
  echo "Error: -d (input directory) and -c (chromosome) are required." >&2
  exit 1
fi

# Integer validations
if ! [[ "$ploidy" =~ ^[0-9]+$ ]] || ! [[ "$threads" =~ ^[0-9]+$ ]]; then
    echo "Error: ploidy and threads must be integers." >&2
    exit 1
fi

# Skip if output already exists
if [ -n "$output_vcf" ] && [ -f "$output_vcf" ]; then
  echo "Warning: Output VCF '$output_vcf' already exists. Skipping."
  exit 0
fi

# Set temp directory
if [ -z "$temp_dir" ]; then
  temp_dir="$input_dir/${chromosome}_extracted_temp"
else
  temp_dir="${temp_dir%/}/${chromosome}_temp"
fi

mkdir -p "$temp_dir"

# --- Extract chromosome from each BAM/CRAM ---
find "$input_dir" -maxdepth 1 -type f \( -name "*.bam" -o -name "*.cram" \) | while IFS= read -r bam_file; do
  echo "Extracting chromosome $chromosome from: $bam_file"
  bash "$EXTRACTOR_SCRIPT" -b "$bam_file" -c "$chromosome" -o "$temp_dir" -p "$threads"
done

echo "Extraction completed. Files saved in: $temp_dir"

# --- Run variant detector if requested ---
if [ -n "$ref_fasta" ] && [ -n "$output_vcf" ]; then
  echo "Running variant detector with ploidy $ploidy..."
  time bash "$VARIANT_SCRIPT" -d "$temp_dir" -r "$ref_fasta" -o "$output_vcf" -p "$ploidy"
  echo "Variant analysis completed: $output_vcf"
elif [ -n "$ref_fasta" ] || [ -n "$output_vcf" ]; then
  echo "Warning: Both -r (reference) and -o (output VCF) must be provided for variant calling."
fi

# --- Cleanup ---
if [ -d "$temp_dir" ]; then
  echo "Removing temporary directory: $temp_dir"
  rm -rf "$temp_dir"
fi

echo "Script finished successfully."
exit 0
