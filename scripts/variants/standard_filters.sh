#!/bin/bash

################################################################################
# Script: standard_filters.sh
# Description:
#   Executes NGSEP's VCFFilter module to filter variants in a VCF file
#   based on quality, read depth, minor allele frequency, and other criteria.
#
# Usage:
#   ./standard_filters.sh -v input.vcf [-o output_prefix] [-r reference.fasta]
#                         [-q min_quality] [-s] [-m max_missing]
#                         [-minRD min_read_depth] [-minMAF min_maf]
#
# Example:
#   ./standard_filters.sh -v sample.vcf -o filtered_sample \
#                         -q 20 -s -m 110 -minRD 20 -minMAF 0.01
################################################################################

# Load configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_BASE="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ -f "$SUITE_BASE/lib/load_config.sh" ]]; then
    source "$SUITE_BASE/lib/load_config.sh"
fi

show_help() {
  echo "Usage: $0 -v input.vcf [-o output_prefix] [-r reference.fasta]"
  echo "                 [-q min_quality] [-s] [-m max_missing]"
  echo "                 [-minRD min_read_depth] [-minMAF min_maf]"
  echo ""
  echo "Options:"
  echo "  -v        Input VCF file to filter (required)"
  echo "  -o        Prefix for output files (default: filtered_output)"
  echo "  -r        Reference genome FASTA file (optional)"
  echo "  -q        Minimum quality score (default: 20)"
  echo "  -s        Apply standard filters (default: enabled)"
  echo "  -m        Minimum individuals genotyped (default: 110)"
  echo "  -minRD    Minimum read depth (default: 20)"
  echo "  -minMAF   Minimum minor allele frequency (default: 0.01)"
  echo "  -h        Display this help message"
  exit 1
}

# Defaults
VCF_INPUT=""
OUTPUT_PREFIX="filtered_output"
REFERENCE=""
MIN_QUALITY=20
STANDARD_FILTERS=true
MAX_MISSING=110
MIN_READ_DEPTH=20
MIN_MAF=0.01

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v)       VCF_INPUT="$2";        shift 2 ;;
    -o)       OUTPUT_PREFIX="$2";    shift 2 ;;
    -r)       REFERENCE="$2";        shift 2 ;;
    -q)       MIN_QUALITY="$2";      shift 2 ;;
    -s)       STANDARD_FILTERS=true; shift ;;
    -m)       MAX_MISSING="$2";      shift 2 ;;
    -minRD)   MIN_READ_DEPTH="$2";   shift 2 ;;
    -minMAF)  MIN_MAF="$2";          shift 2 ;;
    -h)       show_help ;;
    *)        echo "Unknown option: $1"; show_help ;;
  esac
done

if [ -z "$VCF_INPUT" ]; then
  echo "Error: Input VCF file must be provided with -v."
  show_help
fi

if [ ! -f "$VCF_INPUT" ]; then
  echo "Error: Input VCF file '$VCF_INPUT' does not exist."
  exit 1
fi

# Build output filename suffix
SUFFIX="_q${MIN_QUALITY}"
if [ "$STANDARD_FILTERS" = true ]; then SUFFIX+="_s"; fi
SUFFIX+="_m${MAX_MISSING}_minRD${MIN_READ_DEPTH}_minMAF${MIN_MAF}"
OUTPUT_VCF="${OUTPUT_PREFIX}${SUFFIX}.vcf"

if [ -f "$OUTPUT_VCF" ]; then
  echo "Output VCF '$OUTPUT_VCF' already exists. Skipping."
  exit 0
fi

# NGSEP JAR (use config or default)
JAR_PATH="${NGSEP_JAR:-/biodata1/biotools/ngsep/NGSEPcore/NGSEPcore_5.0.0.jar}"
JAVA_OPTS="-XX:MaxHeapSize=${JVM_MAX_HEAP:-30g}"

# Build command
CMD="${JAVA_BIN:-java} ${JAVA_OPTS} -jar \"${JAR_PATH}\" VCFFilter -i \"${VCF_INPUT}\" -o \"${OUTPUT_VCF}\""
[ -n "$REFERENCE" ]      && CMD+=" -r \"${REFERENCE}\""
[ -n "$MIN_QUALITY" ]    && CMD+=" -q ${MIN_QUALITY}"
[ "$STANDARD_FILTERS" = true ] && CMD+=" -s"
[ -n "$MAX_MISSING" ]    && CMD+=" -m ${MAX_MISSING}"
[ -n "$MIN_READ_DEPTH" ] && CMD+=" -minRD ${MIN_READ_DEPTH}"
[ -n "$MIN_MAF" ]        && CMD+=" -minMAF ${MIN_MAF}"

echo "Running NGSEP VCFFilter..."
echo "Output: $OUTPUT_VCF"
eval $CMD

if [ $? -eq 0 ]; then
  echo "Filtering completed successfully."
else
  echo "Error: Filtering failed."
  exit 1
fi
