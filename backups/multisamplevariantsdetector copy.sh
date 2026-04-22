#!/bin/bash

###############################################################################
# Script: run_ngsep.sh
# Description: Run NGSEP MultisampleVariantsDetector with all .bam and .cram
#              files found in one or more specified directories, excluding
#              files with 'tmp' in their name.
#
# Usage:
#   ./multisamplevariantsdetector.sh -d <dir1> <dir2> ... -r <reference.fasta> -o <output.vcf>
#
# Requirements:
#   - Java 8+
#   - NGSEP .jar file
#   - BAM/CRAM files must be indexed
###############################################################################

show_help() {
  echo "Usage: $0 -d <dir1> <dir2> [...] -r <reference.fasta> -o <output.vcf>"
  echo ""
  echo "  -d    One or more directories with .bam/.cram files"
  echo "  -r    Reference genome in FASTA format"
  echo "  -o    Output VCF file"
  exit 1
}

# Initialize
INPUT_DIRS=()
REF_GENOME=""
OUTPUT_VCF=""

# Parse arguments manually
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -d)
      shift
      while [[ "$1" && "$1" != -* ]]; do
        INPUT_DIRS+=("$1")
        shift
      done
      ;;
    -r)
      REF_GENOME="$2"
      shift 2
      ;;
    -o)
      OUTPUT_VCF="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown parameter: $1"
      show_help
      ;;
  esac
done

# Validations
if [[ "${#INPUT_DIRS[@]}" -eq 0 || -z "$REF_GENOME" || -z "$OUTPUT_VCF" ]]; then
  echo "Error: Missing required arguments"
  show_help
fi

for dir in "${INPUT_DIRS[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "Error: Directory does not exist: $dir"
    exit 1
  fi
done

if [[ ! -f "$REF_GENOME" ]]; then
  echo "Error: Reference file not found: $REF_GENOME"
  exit 1
fi

# Collect all BAM/CRAM files, excluding those with 'tmp' in their name
readarray -t READ_FILES < <(
  for dir in "${INPUT_DIRS[@]}"; do
    find "$dir" -type f \( -name "*.bam" -o -name "*.cram" \) ! -name "*tmp*"
  done
)

if [[ "${#READ_FILES[@]}" -eq 0 ]]; then
  echo "Error: No BAM or CRAM files found in specified directories"
  exit 1
fi

# Run NGSEP
echo "Running NGSEP MultisampleVariantsDetector..."
echo "Reference: $REF_GENOME"
echo "Output VCF: $OUTPUT_VCF"
echo "Input files:"
printf " - %s\n" "${READ_FILES[@]}"
echo ""

# Execute NGSEP
time java -XX:MaxHeapSize=1T -Xms1T -Xmx1T -jar  /biodata1/biotools/ngsep/NGSEPcore/NGSEPcore_5.0.0.jar \
  MultisampleVariantsDetector \
  -r "$REF_GENOME" \
  -o "$OUTPUT_VCF" \
  -ploidy 10 \
  -minMQ 30 \
  -maxBaseQS 30 \
  "${READ_FILES[@]}"