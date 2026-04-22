#!/bin/bash

# ============================================================================
# Script: multisample_variant_detector_freebayes.sh
# Description: Runs FreeBayes variant caller on multiple BAM/CRAM files
#              from one or more specified directories.
#
# Usage:
#   bash multisample_variant_detector_freebayes.sh -d /path1 /path2 -o output.vcf
#
# Parameters:
#   -d: One or more directories containing BAM/CRAM files (space-separated)
#   -o: Output VCF filename
# ============================================================================

# -----------------------------------------------
# Load configuration if available
# -----------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_BASE="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ -f "$SUITE_BASE/lib/load_config.sh" ]]; then
    source "$SUITE_BASE/lib/load_config.sh"
fi

# -----------------------------------------------
# Parse -d (directories) and -o (output vcf)
# -----------------------------------------------
INPUT_DIRS=()
OUTPUT_VCF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d)
      shift
      while [[ $# -gt 0 && "$1" != -* ]]; do
        INPUT_DIRS+=("$1")
        shift
      done
      ;;
    -o)
      OUTPUT_VCF="$2"
      shift 2
      ;;
    -r)
      REFERENCE_OVERRIDE="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Use default dirs if not provided
if [ ${#INPUT_DIRS[@]} -eq 0 ]; then
  echo "Error: You must specify at least one input directory with -d."
  exit 1
fi

# Use default output VCF name if not provided
if [ -z "$OUTPUT_VCF" ]; then
  OUTPUT_VCF="output_freebayes.vcf"
fi

# Reference: override in config or use default
REFERENCE="${REFERENCE_OVERRIDE:-${REFERENCE_DEFAULT:-/biodata7/proyectos/ensamblajeCC01-1940/v2/genoma_enmascarado/cc-01-1940_flye_polishing_allhic_ngsepBuilder_enmascarado.fasta}}"

# -----------------------------------------------
# Collect BAM/CRAM files from input directories
# -----------------------------------------------
FILES=""
for DIR in "${INPUT_DIRS[@]}"; do
  for EXT in bam cram; do
    for FILE in "$DIR"/*.$EXT; do
      [ -e "$FILE" ] && FILES+="$FILE "
    done
  done
done

if [ -z "$FILES" ]; then
  echo "Error: No .bam or .cram files found in the specified directories."
  exit 1
fi

echo "Reference: $REFERENCE"
echo "Output VCF: $OUTPUT_VCF"
echo "Running FreeBayes..."

# -----------------------------------------------
# Run FreeBayes
# -----------------------------------------------
freebayes \
  -f "$REFERENCE" \
  --ploidy 10 \
  --min-alternate-fraction 0.1 \
  --min-alternate-count 4 \
  --min-mapping-quality 30 \
  --min-base-quality 30 \
  $FILES > "$OUTPUT_VCF"

echo "FreeBayes completed. Output: $OUTPUT_VCF"
