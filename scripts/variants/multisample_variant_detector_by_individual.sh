#!/bin/bash

# ------------------------------------------------------------------
# Script: multisample_variant_detector_by_individual.sh
# Description: Processes a BAM file to generate a VCF file using NGSEP.
# Usage:
#   ./multisample_variant_detector_by_individual.sh -b <input.bam> -o <output_dir>
#   -b <input.bam>    : Path to the input BAM file.
#   -o <output_dir>   : Directory where the output VCF will be saved.
# ------------------------------------------------------------------

# --------------------------------------------------------------
# Load configuration if available
# --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_BASE="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ -f "$SUITE_BASE/lib/load_config.sh" ]]; then
    source "$SUITE_BASE/lib/load_config.sh"
fi

# Function to display usage
show_usage() {
  echo "Usage: $0 -b <input.bam> -o <output_dir>"
  echo "  -b <input.bam>    : Input BAM file"
  echo "  -o <output_dir>   : Directory where the output VCF will be saved"
  exit 1
}

# Argument parsing
while getopts "b:o:" opt; do
  case "$opt" in
    b) input_bam="$OPTARG" ;;
    o) output_dir="$OPTARG" ;;
    *) show_usage ;;
  esac
done

if [[ -z "${input_bam:-}" || -z "${output_dir:-}" ]]; then
  show_usage
fi

# Deriving Sample ID from BAM name
sample_id=$(basename "$input_bam" .bam)
sample_id=${sample_id%_sorted} # Remove common suffixes if present

mkdir -p "$output_dir"
output_vcf="${output_dir}/${sample_id}.vcf"

echo "Processing sample: $sample_id"
echo "Output VCF: $output_vcf"

# Execute NGSEP SingleSampleVariantsDetector
"${JAVA_BIN:-java}" -XX:MaxHeapSize="${JVM_MAX_HEAP:-30g}" -jar "${NGSEP_JAR:-/biodata1/biotools/ngsep/NGSEPcore/NGSEPcore_5.0.0.jar}" \
  SingleSampleVariantsDetector \
  -i "$input_bam" \
  -o "${output_vcf%.vcf}" \
  -sampleId "$sample_id" \
  -r "${REFERENCE_DEFAULT:-/biodata5/proyectos/llamado_variantes_olivier/referencia_r570/SofficinarumxspontaneumR570_771_v2.0_monoploid.hardmasked.fasta}" \
  -ploidy 10 \
  -minMQ 30 \
  -maxBaseQS 30 \
  -ignore5 5 \
  -ignore3 5 \
  -maxAlnsPerStartPos 100

echo "Finished processing sample $sample_id."
