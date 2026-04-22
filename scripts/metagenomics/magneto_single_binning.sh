#!/bin/bash

# ------------------------------------------------------------------
# Script: magneto_single_binning.sh
# Description: Automates the metagenomics binning workflow using
#              BWA index verification, jgi_summarize_bam_contig_depths
#              for coverage calculation, and MetaBAT2 for binning.
#
# Usage:
#   bash magneto_single_binning.sh -g <assembly.fasta> -b <aligned.bam> -o <output_dir>
#
# Examples:
#   bash magneto_single_binning.sh -g D9.contigs.fa -b J11.sorted.bam -o bins/project_bins
#   bash magneto_single_binning.sh -g contigs/D9.contigs.fa -b mapped/J11.sorted.bam -o bins/bin_D9
#
# Parameters:
#   -g    Path to the assembly FASTA file (e.g., D9.contigs.fa)
#   -b    Path to aligned BAM file (e.g., J11.sorted.bam)
#   -o    Output directory for all results (bins + depth file).
#         Directory basename is used as bin filename prefix.
#   -h    Show this help message
# ------------------------------------------------------------------

GENOME_FASTA=""
ALIGNED_BAM=""
RESULTS_OUTPUT_DIR=""

usage() {
    echo "Usage: $0 -g <assembly.fasta> -b <aligned.bam> -o <output_dir>"
    echo ""
    echo "Options:"
    echo "  -g    Path to the genome/assembly FASTA file."
    echo "  -b    Path to the aligned BAM file."
    echo "  -o    Output directory for all results (bins and depth file)."
    echo "        The directory name will be used as the bin filename prefix."
    echo "        e.g., -o 'results/project_X' creates 'results/project_X/project_X.1.fa'"
    echo "  -h    Show this help message."
    exit 1
}

while getopts "g:b:o:h" opt; do
    case ${opt} in
        g) GENOME_FASTA=$OPTARG      ;;
        b) ALIGNED_BAM=$OPTARG       ;;
        o) RESULTS_OUTPUT_DIR=$OPTARG ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :)  echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done
shift $((OPTIND -1))

if [ -z "$GENOME_FASTA" ] || [ -z "$ALIGNED_BAM" ] || [ -z "$RESULTS_OUTPUT_DIR" ]; then
    echo "Error: Missing required parameters."
    usage
fi

# Normalize path (remove trailing slash)
RESULTS_OUTPUT_DIR=$(echo "$RESULTS_OUTPUT_DIR" | sed 's/\/$//')
BIN_FILENAME_PREFIX=$(basename "$RESULTS_OUTPUT_DIR")

if [ -z "$BIN_FILENAME_PREFIX" ]; then
    echo "Error: Invalid output directory — cannot determine bin filename prefix." >&2
    usage
fi

METABAT_OUTPUT_PREFIX="${RESULTS_OUTPUT_DIR}/${BIN_FILENAME_PREFIX}"

echo "--- Starting metagenomics binning workflow ---"
echo "Assembly FASTA:   $GENOME_FASTA"
echo "Aligned BAM:      $ALIGNED_BAM"
echo "Output directory: $RESULTS_OUTPUT_DIR"
echo "Bin file prefix:  $BIN_FILENAME_PREFIX"

# Activate Conda environment
echo "Activating Conda environment..."
eval "$(conda shell.bash hook)"
conda activate /biodata4/ambientes_conda/miniforge3/envs/bowtie_env_py310/

if [ $? -ne 0 ]; then
    echo "Error: Failed to activate Conda environment."
    exit 1
fi
echo "Conda environment activated."

# Verify BWA indexes
INDEX_FILES=(
    "$GENOME_FASTA.amb"
    "$GENOME_FASTA.ann"
    "$GENOME_FASTA.bwt"
    "$GENOME_FASTA.pac"
    "$GENOME_FASTA.sa"
)

INDEX_EXISTS=true
for f in "${INDEX_FILES[@]}"; do
    [ ! -f "$f" ] && INDEX_EXISTS=false && break
done

if $INDEX_EXISTS; then
    echo "BWA indexes already exist for $GENOME_FASTA."
else
    echo "Error: BWA indexes not found for $GENOME_FASTA."
    echo "Please run: bwa index $GENOME_FASTA"
    exit 1
fi

# Create output directory
mkdir -p "$RESULTS_OUTPUT_DIR"

# Calculate depth of coverage per contig
BAM_BASENAME=$(basename "$ALIGNED_BAM")
GENOME_BASENAME=$(basename "$GENOME_FASTA")
GENOME_BASENAME="${GENOME_BASENAME%.*}"
DEPTH_FILE="${RESULTS_OUTPUT_DIR}/depth_${GENOME_BASENAME}_${BAM_BASENAME}.txt"

echo "Calculating contig coverage depth..."
echo "Depth file: $DEPTH_FILE"
jgi_summarize_bam_contig_depths --outputDepth "$DEPTH_FILE" "$ALIGNED_BAM"

if [ $? -ne 0 ]; then
    echo "Error: Coverage depth calculation failed."
    exit 1
fi
echo "Coverage calculation completed: $DEPTH_FILE"

# Run MetaBAT2
echo "Running MetaBAT2 for binning..."
echo "MetaBAT2 output prefix: $METABAT_OUTPUT_PREFIX"
metabat2 -i "$GENOME_FASTA" -a "$DEPTH_FILE" -o "$METABAT_OUTPUT_PREFIX"

if [ $? -ne 0 ]; then
    echo "Error: MetaBAT2 execution failed."
    exit 1
fi
echo "MetaBAT2 completed. Bins generated in: $RESULTS_OUTPUT_DIR (prefix: $BIN_FILENAME_PREFIX)"
echo "--- Binning workflow completed successfully ---"
