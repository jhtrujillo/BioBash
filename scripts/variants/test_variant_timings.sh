#!/bin/bash

# ------------------------------------------------------------------
# Script: test_variant_timings.sh
# Description: This script tests the execution time of variant 
#              calling pipelines (GATK, NGSEP, etc.) with a 
#              specified number of samples.
# Usage:
#   ./test_variant_timings.sh <number_of_samples>
# ------------------------------------------------------------------

# --------------------------------------------------------------
# Load configuration if available
# --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_BASE="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ -f "$SUITE_BASE/lib/load_config.sh" ]]; then
    source "$SUITE_BASE/lib/load_config.sh"
fi

sample_count=$1

if [ -z "$sample_count" ]; then
    echo "Usage: $0 <number_of_samples>"
    exit 1
fi

# Paths and Names
REF="${REFERENCE_DEFAULT:-/biodata7/proyectos/ensamblajeCC01-1940/v2/genoma_enmascarado/cc-01-1940_flye_polishing_allhic_ngsepBuilder_enmascarado.fasta}"
GATK_SCRIPT="$SUITE_BASE/scripts/variants/gatk_parallel_pipeline.sh"
BAM_SOURCE="../all_bams/scaffold_65961_temp/"
LOG_DIR="logs"
OUT_DIR="ind_${sample_count}"

# Create directories if they don't exist
mkdir -p "$LOG_DIR" "$OUT_DIR"

# Cleanup: delete all files except scripts in current directory
echo "Cleaning up current directory..."
find . -maxdepth 1 -type f ! -name "*.sh" -exec rm -f {} \;

# Copy the first N BAMs
echo "Copying $sample_count BAM files..."
ls "$BAM_SOURCE"/*.bam 2>/dev/null | head -n "$sample_count" | parallel -j1 "cp {} ."

# Index BAMs if .bai is missing
echo "Indexing BAM files..."
for bam in *_all_sorted.bam; do
  if [ -f "$bam" ]; then
    [ -f "${bam}.bai" ] || samtools index "$bam"
  fi
done

# --- GATK Section (Currently disabled) ---
# echo ">> Running GATK with ${sample_count} samples..."
# { time bash "$GATK_SCRIPT" \
#     --ref "$REF" \
#     --ploidy 10 \
#     --threads 80 \
#     ...
# }

echo "Timings test setup complete for $sample_count samples."
