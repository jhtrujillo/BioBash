#!/bin/bash

################################################################################
# Script: find_variants.sh
# Description:
#   Runs NGSEP to detect variants in an individual sample using an input BAM file.
#   A VCF file with known variants can be included if specified.
#
# Usage:
#   ./find_variants.sh -b <bam_path> -o <output_vcf> [-k <known_vcf>]
#
# Example:
#   ./find_variants.sh -b sample01_aln_sorted.bam \
#                      -o /path/output/sample01_variant.vcf \
#                      -k /path/AllSamples_variants.vcf
################################################################################

# ----------------------------------------------------------------------------
# Load configuration if available (standalone execution support)
# ----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_BASE="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ -f "$SUITE_BASE/lib/load_config.sh" ]]; then
    source "$SUITE_BASE/lib/load_config.sh"
fi

# ----------------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------------
while getopts "b:o:k:" opt; do
    case "$opt" in
        b) bam_path="$OPTARG" ;;
        o) output_vcf="$OPTARG" ;;
        k) known_vcf="$OPTARG" ;;
        *)
            echo "Usage: $0 -b <bam_path> -o <output_vcf> [-k <known_vcf>]"
            exit 1
            ;;
    esac
done

# Verify mandatory parameters
if [[ -z "$bam_path" || -z "$output_vcf" ]]; then
    echo "Error: You must provide the BAM file path with -b and the output VCF file with -o."
    echo "Usage: $0 -b <bam_path> -o <output_vcf> [-k <known_vcf>]"
    exit 1
fi

# ----------------------------------------------------------------------------
# Extract filename and directory
# ----------------------------------------------------------------------------
filename=$(basename "$bam_path")
dir_path=$(dirname "$bam_path")
sample_id=$(echo "$filename" | cut -d'_' -f1)

# (Optional) Display processed file information
printf "Processing file: %s\n" "$filename"
printf "Directory: %s\n" "$dir_path"

# ----------------------------------------------------------------------------
# Configuration and Path derivation
# ----------------------------------------------------------------------------
# Default reference (can be overridden in biobash.conf if added there, 
# otherwise keep this default for compatibility with olivier's project)
REFERENCE="${REFERENCE_DEFAULT:-/biodata5/proyectos/llamado_variantes_olivier/referencia_r570/SofficinarumxspontaneumR570_771_v2.0_monoploid.hardmasked.fasta}"

# Get base path for output file (without .vcf)
output_base="${output_vcf%.vcf}"
log_file="${output_base}_NGSEP_variant_calling.log"

# ----------------------------------------------------------------------------
# NGSEP Execution (if output file does not already exist)
# ----------------------------------------------------------------------------
if [ ! -f "$output_vcf" ]; then
    echo "Running NGSEP for sample: $sample_id"

    cmd=(
        "${JAVA_BIN:-java}" -XX:MaxHeapSize="${JVM_MAX_HEAP:-30g}" -jar "${NGSEP_JAR:-/biodata1/biotools/ngsep/NGSEPcore/NGSEPcore_5.0.0.jar}" SingleSampleVariantsDetector
    )

    # Add -knownVariants if specified
    if [ -n "$known_vcf" ]; then
        cmd+=( -knownVariants "$known_vcf" )
    fi

    # Common parameters
    cmd+=(
        -sampleId "$sample_id"
        -ploidy 10
        -minMQ 30
        -maxBaseQS 30
        -ignore5 5
        -ignore3 5
        -maxAlnsPerStartPos 100
        -r "$REFERENCE"
        -o "$output_base"
        -i "$bam_path"
    )

    # Execute full command and redirect output to log
    echo "Executing: ${cmd[*]}"
    "${cmd[@]}" >& "$log_file"
else
    printf "Variant file already exists: %s\n" "$output_vcf"
fi

echo "Process completed for sample ${sample_id}."
