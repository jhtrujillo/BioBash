#!/bin/bash

# ------------------------------------------------------------------
# Script: split_proteins.sh
# Description: Splits a protein FASTA file into multiple smaller files,
#              each containing a maximum number of sequences.
#
# Usage:
#   ./split_proteins.sh -p <input.fasta> -o <output_prefix> -n <max_proteins>
#
# Options:
#   -p    Input FASTA file (required)
#   -o    Output file prefix (required)
#   -n    Maximum number of proteins per output file (default: 1200)
# ------------------------------------------------------------------

show_usage() {
  echo "Usage: $0 -p <input.fasta> -o <output_prefix> -n <max_proteins>"
  echo "  -p <input.fasta>     : Input FASTA file."
  echo "  -o <output_prefix>   : Prefix for output files."
  echo "  -n <max_proteins>    : Maximum number of proteins per file (default: 1200)."
  exit 1
}

# Default value
max_proteins=1200

# Parse arguments
while getopts ":p:o:n:" opt; do
  case ${opt} in
    p) input_fasta=$OPTARG ;;
    o) output_prefix=$OPTARG ;;
    n) max_proteins=$OPTARG ;;
    *) show_usage ;;
  esac
done

# Validate arguments
if [ -z "$input_fasta" ] || [ -z "$output_prefix" ]; then
  show_usage
fi

if ! [[ "$max_proteins" =~ ^[0-9]+$ ]] || (( max_proteins < 1 )); then
  echo "Error: Maximum number of proteins must be a positive integer."
  show_usage
fi

if [ ! -f "$input_fasta" ]; then
  echo "Error: File '$input_fasta' does not exist."
  exit 1
fi

# Initialization
file_counter=1
protein_counter=0
output_file="${output_prefix}_${file_counter}.fasta"
> "$output_file"
declare -A count_per_file

# Process line by line
while IFS= read -r line; do
  if [[ "$line" == ">"* ]]; then
    if (( protein_counter == max_proteins )); then
      count_per_file["$output_file"]=$protein_counter
      file_counter=$((file_counter + 1))
      output_file="${output_prefix}_${file_counter}.fasta"
      > "$output_file"
      protein_counter=0
    fi
    protein_counter=$((protein_counter + 1))
  fi
  echo "$line" >> "$output_file"
done < "$input_fasta"

# Save last count
count_per_file["$output_file"]=$protein_counter

# Report
echo "Split completed. Proteins per file (max $max_proteins):"
for file in "${!count_per_file[@]}"; do
  echo "  $file: ${count_per_file[$file]} proteins"
done
