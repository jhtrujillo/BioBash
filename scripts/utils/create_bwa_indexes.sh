#!/bin/bash

# ------------------------------------------------------------------
# Script: create_bwa_indexes.sh
# Description: Creates BWA indexes for a reference genome FASTA file.
#              Skips indexing if indexes already exist.
#
# Usage:
#   ./create_bwa_indexes.sh -g <reference_genome.fasta>
# ------------------------------------------------------------------

show_usage() {
    echo "Usage: $0 -g <reference_genome.fasta>"
    exit 1
}

while getopts ":g:" opt; do
  case $opt in
    g) GENOME_FASTA="$OPTARG" ;;
    *) show_usage ;;
  esac
done

if [ -z "${GENOME_FASTA:-}" ]; then
    show_usage
fi

if [ ! -f "$GENOME_FASTA" ]; then
    echo "Error: Genome file not found: $GENOME_FASTA"
    exit 1
fi

# Check if BWA index files already exist
INDEX_FILES=(
    "$GENOME_FASTA.amb"
    "$GENOME_FASTA.ann"
    "$GENOME_FASTA.bwt"
    "$GENOME_FASTA.pac"
    "$GENOME_FASTA.sa"
)

INDEX_EXISTS=true
for index_file in "${INDEX_FILES[@]}"; do
    if [ ! -f "$index_file" ]; then
        INDEX_EXISTS=false
        break
    fi
done

if $INDEX_EXISTS; then
    echo "BWA indexes already exist for: $GENOME_FASTA"
    echo "Skipping indexing."
else
    echo "Creating BWA index for: $GENOME_FASTA..."
    bwa index "$GENOME_FASTA"

    if [ $? -ne 0 ]; then
        echo "Error: BWA indexing failed."
        exit 1
    fi
    echo "BWA indexing completed successfully."
fi

echo "--- BWA indexing script finished ---"
