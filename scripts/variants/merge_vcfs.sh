#!/bin/bash

################################################################################
# Script: merge_vcfs.sh
# Description:
#   Runs NGSEP's VCFMerge module to merge multiple valid VCF files
#   from a specified directory into a single output VCF file.
#
# Features:
#   - Auto-generates sequence names file if missing
#   - Skips empty or invalid VCFs
#   - Logs everything to merge_vcfs.log
#
# Usage:
#   ./merge_vcfs.sh -d <vcf_directory> -o <output_merged.vcf>
################################################################################

# Load configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_BASE="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ -f "$SUITE_BASE/lib/load_config.sh" ]]; then
    source "$SUITE_BASE/lib/load_config.sh"
fi

# Config paths (fallback to defaults if not in config)
NGSEP_JAR="${NGSEP_JAR:-/biodata1/biotools/ngsep/NGSEPcore/NGSEPcore_5.0.0.jar}"
REFERENCE_FASTA="${REFERENCE_FASTA:-/biodata7/proyectos/ensamblajeCC01-1940/v2/genoma_enmascarado/cc-01-1940_flye_polishing_allhic_ngsepBuilder_enmascarado.fasta}"
SEQ_NAMES="${SEQ_NAMES:-/biodata7/proyectos/ensamblajeCC01-1940/v2/genoma_enmascarado/reference_seqNames.txt}"
JAVA_OPTS="-Xms160g -Xmx${JVM_MAX_HEAP:-160g}"
LOG_FILE="merge_vcfs.log"

usage() {
    echo "Usage: $0 -d <vcf_directory> -o <output_merged.vcf>"
    exit 1
}

while getopts "d:o:" opt; do
    case "$opt" in
        d) vcf_dir="$OPTARG" ;;
        o) output_vcf="$OPTARG" ;;
        *) usage ;;
    esac
done

if [[ -z "$vcf_dir" || -z "$output_vcf" ]]; then
    usage
fi

# Start log
{
echo "=========================="
echo "Merge started: $(date)"
echo "VCF directory: $vcf_dir"
echo "Output file:   $output_vcf"
} >> "$LOG_FILE"

# Generate sequence names file if needed
if [[ ! -f "$SEQ_NAMES" ]]; then
    echo "Sequence names file not found. Generating from reference..." | tee -a "$LOG_FILE"
    if [[ ! -f "$REFERENCE_FASTA" ]]; then
        echo "ERROR: Reference FASTA not found at $REFERENCE_FASTA" | tee -a "$LOG_FILE"
        exit 1
    fi
    awk '{if(substr($1,1,1)==">") print substr($1,2) }' "$REFERENCE_FASTA" > "$SEQ_NAMES"
    echo "Sequence names file generated: $SEQ_NAMES" >> "$LOG_FILE"
fi

# Skip if output already exists
if [[ -f "$output_vcf" ]]; then
    echo "Output file already exists: $output_vcf" | tee -a "$LOG_FILE"
    exit 0
fi

# Collect and validate VCFs
valid_vcfs=()
echo "Checking VCF files..." | tee -a "$LOG_FILE"

for file in "$vcf_dir"/*.vcf; do
    [[ -e "$file" ]] || continue
    non_header_lines=$(grep -cv '^#' "$file")
    if [[ $non_header_lines -gt 0 ]]; then
        valid_vcfs+=("$file")
    else
        echo "Skipped (empty or invalid): $file" | tee -a "$LOG_FILE"
    fi
done

if [[ ${#valid_vcfs[@]} -eq 0 ]]; then
    echo "No valid VCFs found to merge. Aborting." | tee -a "$LOG_FILE"
    exit 1
fi

{
echo "Valid VCF files to merge (${#valid_vcfs[@]}):"
for f in "${valid_vcfs[@]}"; do echo " - $f"; done
} | tee -a "$LOG_FILE"

# Run NGSEP VCFMerge
echo "Running NGSEP VCFMerge..." | tee -a "$LOG_FILE"
java $JAVA_OPTS -jar "$NGSEP_JAR" VCFMerge \
    -s "$SEQ_NAMES" \
    -o "$output_vcf" \
    "${valid_vcfs[@]}" >> "$LOG_FILE" 2>&1

echo "Merge completed successfully at $(date)." | tee -a "$LOG_FILE"
echo "Output: $output_vcf" >> "$LOG_FILE"
