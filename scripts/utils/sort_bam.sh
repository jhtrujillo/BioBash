#!/bin/bash

# --------------------------------------------------------------
# Script: sort_bam_cram.sh
# Author: Jhon Henry Trujillo + AI
# Date: April 24, 2025
# Description:
#   Sorts a BAM or CRAM file using samtools sort.
#   If the output file already exists, no action is taken.
#   Optionally allows specifying the number of processors.
#
# Usage:
#   ./sort_bam_cram.sh -b <input_file.bam|cram> -o <output_file.bam> [-p <processors>]
# Example:
#   ./sort_bam_cram.sh -b unsorted_file.bam -o sorted_file.bam
#   ./sort_bam_cram.sh -b my_file.cram -o my_sorted_file.bam -p 8
# --------------------------------------------------------------

# --------------------------------------------------------------
# Function to display help
# --------------------------------------------------------------
show_help() {
  echo "Usage: $0 -b <input_file.bam|cram> -o <output_file.bam> [-p <processors>]"
  exit 1
}

# --------------------------------------------------------------
# Function to print an error message and exit
# --------------------------------------------------------------
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# --------------------------------------------------------------
# Define expected options
# --------------------------------------------------------------
input_file=""
output_file=""
processors=1  # Default value

# --------------------------------------------------------------
# Parse command-line arguments
# --------------------------------------------------------------
while getopts ":b:o:p:" option; do
  case $option in
    b) input_file="$OPTARG" ;;
    o) output_file="$OPTARG" ;;
    p)
      processors="$OPTARG"
      if [[ ! "$processors" =~ ^[0-9]+$ || "$processors" -lt 1 ]]; then
        error_exit "The number of processors must be a positive integer."
      fi
      ;;
    *) show_help ;;
  esac
done

# --------------------------------------------------------------
# Verify that the required arguments were provided
# --------------------------------------------------------------
if [ -z "$input_file" ] || [ -z "$output_file" ]; then
  show_help
fi

# --------------------------------------------------------------
# Verify that the input file exists and has the correct extension
# --------------------------------------------------------------
if [ ! -f "$input_file" ]; then
  error_exit "Error: The input file '$input_file' does not exist."
fi

if [[ ! "$input_file" =~ \.(bam|cram)$ ]]; then
  error_exit "Error: The input file '$input_file' must have the .bam or .cram extension."
fi

# --------------------------------------------------------------
# Verify that the output file does not exist
# --------------------------------------------------------------
if [ -f "$output_file" ]; then
  echo "The output file '$output_file' already exists. No action will be taken."
  exit 0
fi

# --------------------------------------------------------------
# Create the output directory if it doesn't exist
# --------------------------------------------------------------
output_directory=$(dirname "$output_file")
mkdir -p "$output_directory"

# --------------------------------------------------------------
# Sort the file using samtools sort with the processors option
# --------------------------------------------------------------
echo "Sorting '$input_file' using $processors processor(s)..."
samtools sort -o "$output_file" -@ "$processors" "$input_file"

# --------------------------------------------------------------
# Verify if samtools sort was successful
# --------------------------------------------------------------
if [ $? -eq 0 ]; then
  echo "Sorted file saved to: '$output_file'"
else
  echo "Error: File sorting failed."
  exit 1
fi

# --------------------------------------------------------------
# End of script
# --------------------------------------------------------------
exit 0