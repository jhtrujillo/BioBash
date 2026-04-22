#!/bin/bash

################################################################################
# Script: run_ngsep_vcffilter.sh
# Description:
#   This script executes NGSEP's VCFFilter module to filter variants in a VCF
#   file based on quality, read depth, minor allele frequency, and other criteria.
#   The input VCF file is specified with the -v option. Optionally, a reference
#   genome FASTA file can be provided with the -r option.
#
# Usage:
#   ./run_ngsep_vcffilter.sh -v input.vcf [-o output_prefix] [-r reference.fasta]
#                            [-q min_quality] [-s] [-m max_missing]
#                            [-minRD min_read_depth] [-minMAF min_maf]
#
# Example:
#   ./run_ngsep_vcffilter.sh -v sample.vcf -o filtered_sample \
#                            -q 20 -s -m 110 -minRD 20 -minMAF 0.01
#
# Author: Jhon Henry Trujillo Montenegro
# Date: May 12, 2025
################################################################################

# Function to display help
show_help() {
  echo "Usage: $0 -v input.vcf [-o output_prefix] [-r reference.fasta]"
  echo "                 [-q min_quality] [-s] [-m max_missing]"
  echo "                 [-minRD min_read_depth] [-minMAF min_maf]"
  echo
  echo "Options:"
  echo "  -v        Input VCF file to filter (required)"
  echo "  -o        Prefix for output files (default: filtered_output)"
  echo "  -r        Reference genome FASTA file (optional)"
  echo "  -q        Minimum quality score (default: 20)"
  echo "  -s        Apply standard filters (default: enabled)"
  echo "  -m        Minimum of individuls genotyped (default: 110)"
  echo "  -minRD    Minimum read depth (default: 20)"
  echo "  -minMAF   Minimum minor allele frequency (default: 0.01)"
  echo "  -h        Display this help message"
  exit 1
}

# Initialize variables with default values
VCF_INPUT=""
OUTPUT_PREFIX="filtered_output"
REFERENCE=""
MIN_QUALITY=20
STANDARD_FILTERS=true
MAX_MISSING=110
MIN_READ_DEPTH=20
MIN_MAF=0.01

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v)
      VCF_INPUT="$2"
      shift 2
      ;;
    -o)
      OUTPUT_PREFIX="$2"
      shift 2
      ;;
    -r)
      REFERENCE="$2"
      shift 2
      ;;
    -q)
      MIN_QUALITY="$2"
      shift 2
      ;;
    -s)
      STANDARD_FILTERS=true
      shift
      ;;
    -m)
      MAX_MISSING="$2"
      shift 2
      ;;
    -minRD)
      MIN_READ_DEPTH="$2"
      shift 2
      ;;
    -minMAF)
      MIN_MAF="$2"
      shift 2
      ;;
    -h)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      ;;
  esac
done

# Check if input VCF file is provided
if [ -z "$VCF_INPUT" ]; then
  echo "Error: You must provide an input VCF file with the -v option."
  show_help
fi

# Check if input VCF file exists
if [ ! -f "$VCF_INPUT" ]; then
  echo "Error: Input VCF file '$VCF_INPUT' does not exist."
  exit 1
fi

# Construct output filename suffix based on specified parameters
SUFFIX="_q${MIN_QUALITY}"
if [ "$STANDARD_FILTERS" = true ]; then
  SUFFIX+="_s"
fi
SUFFIX+="_m${MAX_MISSING}_minRD${MIN_READ_DEPTH}_minMAF${MIN_MAF}"

# Set output VCF file name
OUTPUT_VCF="${OUTPUT_PREFIX}${SUFFIX}.vcf"

# Check if output VCF file already exists
if [ -f "$OUTPUT_VCF" ]; then
  echo "Output VCF file '$OUTPUT_VCF' already exists. Skipping filtering."
  exit 0
fi

# Set path to NGSEP JAR file
JAR_PATH="/biodata1/biotools/ngsep/NGSEPcore/NGSEPcore_5.0.0.jar"

# Set Java memory options
JAVA_OPTS="-XX:MaxHeapSize=30g"

# Construct the command
CMD="java ${JAVA_OPTS} -jar \"${JAR_PATH}\" VCFFilter -i \"${VCF_INPUT}\" -o \"${OUTPUT_VCF}\""

# Add optional parameters
if [ -n "$REFERENCE" ]; then
  CMD+=" -r \"${REFERENCE}\""
fi
if [ -n "$MIN_QUALITY" ]; then
  CMD+=" -q ${MIN_QUALITY}"
fi
if [ "$STANDARD_FILTERS" = true ]; then
  CMD+=" -s"
fi
if [ -n "$MAX_MISSING" ]; then
  CMD+=" -m ${MAX_MISSING}"
fi
if [ -n "$MIN_READ_DEPTH" ]; then
  CMD+=" -minRD ${MIN_READ_DEPTH}"
fi
if [ -n "$MIN_MAF" ]; then
  CMD+=" -minMAF ${MIN_MAF}"
fi

# Execute the command
echo "Running NGSEP VCFFilter..."
eval $CMD

# Check for successful execution
if [ $? -eq 0 ]; then
  echo "Execution completed successfully."
else
  echo "Error during execution."
  exit 1
fi

