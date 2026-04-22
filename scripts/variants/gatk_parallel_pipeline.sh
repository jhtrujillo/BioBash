#!/bin/bash

# --------------------------------------------------------------
# Script: gatk_parallel_pipeline.sh
# Description: Runs GATK HaplotypeCaller in parallel for all BAM files
#              in a directory, then combines GVCFs and genotypes them.
#
# Usage:
#   ./gatk_parallel_pipeline.sh --ref <reference.fasta> --ploidy <int> \
#       --threads <int> --bam-dir <bam_path> --output-vcf <output.vcf.gz>
#
# Example:
#   ./gatk_parallel_pipeline.sh --ref genome.fasta --ploidy 10 --threads 8 \
#       --bam-dir ./bams --output-vcf variants.vcf.gz
# --------------------------------------------------------------

usage() {
  echo "Usage:"
  echo "  $0 --ref <reference.fasta> --ploidy <int> --threads <int> --bam-dir <bam_path> --output-vcf <output.vcf.gz>"
  echo ""
  echo "Example:"
  echo "  $0 --ref genome.fasta --ploidy 10 --threads 8 --bam-dir ./bams --output-vcf variants.vcf.gz"
  exit 1
}

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --ref)     REF="$2";        shift ;;
    --ploidy)  PLOIDY="$2";     shift ;;
    --threads) THREADS="$2";    shift ;;
    --bam-dir) BAM_DIR="$2";   shift ;;
    --output-vcf) OUTPUT_VCF="$2"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown parameter: $1"; usage ;;
  esac
  shift
done

# Validate mandatory parameters
if [ -z "$REF" ] || [ -z "$PLOIDY" ] || [ -z "$THREADS" ] || [ -z "$BAM_DIR" ] || [ -z "$OUTPUT_VCF" ]; then
  echo "Error: Missing mandatory parameters."
  usage
fi

# Verify reference file
if [ ! -f "$REF" ]; then
  echo "Error: Reference file not found: $REF"
  exit 1
fi

# Generate .dict if missing
DICT="${REF%.fasta}.dict"
if [ ! -f "$DICT" ]; then
  echo "Sequence dictionary (.dict) not found. Generating..."
  gatk CreateSequenceDictionary -R "$REF"
fi

# Generate .fai if missing
if [ ! -f "$REF.fai" ]; then
  echo "FASTA index (.fai) not found. Generating..."
  samtools faidx "$REF"
fi

# Verify BAM directory
if [ ! -d "$BAM_DIR" ]; then
  echo "Error: BAM directory not found: $BAM_DIR"
  exit 1
fi

# Run HaplotypeCaller in parallel for each BAM
echo "Running HaplotypeCaller in parallel across all BAM files..."
find "$BAM_DIR" -name "*.bam" | parallel -j "$THREADS" --joblog parallel_hc.log --verbose '
  BAM={}
  SAMPLE=$(basename {} _all_sorted.bam)
  echo "Processing sample: $SAMPLE"
  gatk HaplotypeCaller \
    -R '"$REF"' \
    -I "$BAM" \
    -O ${SAMPLE}.g.vcf.gz \
    --emit-ref-confidence GVCF \
    --sample-ploidy '"$PLOIDY"' \
    --minimum-mapping-quality 30 \
    --min-base-quality-score 30 \
    || echo "ERROR: HaplotypeCaller failed for $SAMPLE" >&2
'

# Validate GVCF files were generated
if ! ls *.g.vcf.gz 1>/dev/null 2>&1; then
  echo "Error: No .g.vcf.gz files were generated. Check parallel_hc.log for errors."
  exit 1
fi

# Create GVCF list
ls *.g.vcf.gz | awk '{print "--variant " $1}' > gvcf_list.txt

# Combine GVCFs
echo "Combining GVCFs..."
gatk CombineGVCFs \
  -R "$REF" \
  $(cat gvcf_list.txt) \
  -O combined_tmp.g.vcf.gz

# Joint Genotyping
echo "Running GenotypeGVCFs..."
gatk GenotypeGVCFs \
  -R "$REF" \
  -V combined_tmp.g.vcf.gz \
  -O "$OUTPUT_VCF"

echo "Pipeline completed. Final output: $OUTPUT_VCF"
