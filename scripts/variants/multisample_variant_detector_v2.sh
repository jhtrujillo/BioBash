#!/bin/bash

###############################################################################
# Script: run_ngsep.sh
# Description: Run NGSEP MultisampleVariantsDetector with all .bam and .cram
#              files found in one or more specified directories, excluding
#              files with 'tmp' in their name.
#
# Usage:
#   ./multisamplevariantsdetector.sh -d <dir1> ... -r <ref.fasta> -o <out.vcf> [-p <ploidy>]
#
# Requirements:
#   - Java 8+
#   - NGSEP .jar file
#   - BAM/CRAM files must be indexed
###############################################################################

show_help() {
  echo "Usage: $0 -d <dir1> <dir2> [...] -r <reference.fasta> -o <output.vcf> [-p <ploidy>]"
  echo ""
  echo "  -d    One or more directories with .bam/.cram files (required)"
  echo "  -r    Reference genome in FASTA format (required)"
  echo "  -o    Output VCF file (required)"
  echo "  -p    Ploidy level. Default is 10 (optional)"
  exit 1
}

# Initialize
INPUT_DIRS=()
REF_GENOME=""
OUTPUT_VCF=""
PLOIDY=10 # Default ploidy value

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
    -p)
      PLOIDY="$2"
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

# New validation for ploidy to ensure it is an integer
if ! [[ "$PLOIDY" =~ ^[0-9]+$ ]]; then
    echo "Error: Ploidy value must be an integer. You provided: '$PLOIDY'"
    exit 1
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
echo "Ploidy: $PLOIDY"
echo "Input files:"
printf " - %s\n" "${READ_FILES[@]}"
echo ""

# Execute NGSEP
# NOTE: The redundant memory flags (-Xms160g -Xmx160g and -Xms20024M -Xmx40048M)
# were simplified. The JVM will use the last specified value.
# I've kept the larger value for this example.
java -XX:MaxHeapSize=500g -Xms160g -Xmx160g -jar /biodata1/biotools/ngsep/NGSEPcore/NGSEPcore_5.0.0.jar \
  MultisampleVariantsDetector \
  -r "$REF_GENOME" \
  -o "$OUTPUT_VCF" \
  -ploidy "$PLOIDY" \
  -minMQ 30 \
  -maxBaseQS 30 \
  -ignore5 5 \
  -ignore3 5  \
  -maxAlnsPerStartPos 100 \
  "${READ_FILES[@]}"