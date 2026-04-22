#!/bin/bash

#------------------------------------------------------------------------------
# Script: extract_chromosome.sh
# Author:  Jhon Henry Trujillo Montenegro
# Date:    April 22, 2025
#
# Description:
#   This script extracts reads from a specific chromosome
#   from a BAM or CRAM file. If the index file does not
#   exist, it automatically generates it using the specified
#   number of processors (default: 20). The result is saved
#   in a separate file within the directory indicated by the
#   user or in 'test/' by default.
#
#   This code was developed with the support of ChatGPT and Gemini.
#
# Usage:
#   ./extract_chromosome.sh -b <input.bam|input.cram> \
#                           -c <chromosome> \
#                           [-o <output_directory>] \
#                           [-p <processors>]
#
# Example:
#   ./extract_chromosome.sh -b sample.bam -c chr2 -o results/ -p 8
#   ./extract_chromosome.sh -b sample.bam -c chr2 -o results/
#   (uses 20 processors by default)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Check if samtools is installed
#------------------------------------------------------------------------------
if ! command -v samtools >/dev/null 2>&1; then
    echo "Error: samtools is not installed or not found in the PATH. Please install it."
    exit 1
fi

#------------------------------------------------------------------------------
# Display help function
#------------------------------------------------------------------------------
function display_help {
    echo "Usage: $0 -b <input.bam|input.cram> \
           -c <chromosome> \
           [-o <output_directory>] \
           [-p <processors>]"
    echo "Example: $0 -b sample.bam -c chr2 -o results/ -p 8"
    echo "       $0 -b sample.bam -c chr2 -o results/ (uses 20 processors by default)"
    exit 1
}

#------------------------------------------------------------------------------
# Default values
#------------------------------------------------------------------------------
output_directory="test"
processors=20 # Default to 20 processors

#------------------------------------------------------------------------------
# Parse arguments
#------------------------------------------------------------------------------
while getopts ":b:c:o:p:" option; do
    case $option in
        b) input_file="$OPTARG"    ;;
        c) chromosome="$OPTARG"    ;;
        o) output_directory="$OPTARG" ;;
        p) processors="$OPTARG"     ;;
        *) display_help             ;;
    esac
done

#------------------------------------------------------------------------------
# Verify that the required arguments are provided
#------------------------------------------------------------------------------
if [ -z "$input_file" ] || [ -z "$chromosome" ]; then
    display_help
fi

#------------------------------------------------------------------------------
# Verify that the input file exists
#------------------------------------------------------------------------------
if [ ! -f "$input_file" ]; then
    echo "Error: The file '$input_file' does not exist."
    exit 1
fi

#------------------------------------------------------------------------------
# Verify that the number of processors is a positive integer
#------------------------------------------------------------------------------
if ! [[ "$processors" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: The number of processors must be a positive integer."
    exit 1
fi

#------------------------------------------------------------------------------
# Determine the file type and index name
#------------------------------------------------------------------------------
extension="${input_file##*.}"
base_name="$(basename "$input_file" ".$extension")"

case "$extension" in
    bam)
        index_file="$input_file.bai" ;;
    cram)
        index_file="$input_file.crai" ;;
    *)
        echo "Error: The file must have a .bam or .cram extension."
        exit 1 ;;
esac

#------------------------------------------------------------------------------
# Create the index if it does not exist
#------------------------------------------------------------------------------
if [ ! -f "$index_file" ]; then
    echo "Generating index for '$input_file' using $processors processor(s)..."
    samtools index -@ "$processors" "$input_file"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate the index."
        exit 1
    fi
else
    echo "Index file exists: '$index_file'"
fi

#------------------------------------------------------------------------------
# Create the output directory if it does not exist
#------------------------------------------------------------------------------
mkdir -p "$output_directory"

#------------------------------------------------------------------------------
# Define the output file name
#------------------------------------------------------------------------------
output_file="$output_directory/${base_name}_chr${chromosome}.${extension}"

#------------------------------------------------------------------------------
# Check if the output file already exists
#------------------------------------------------------------------------------
if [ -f "$output_file" ]; then
    echo "The output file '$output_file' already exists. No action will be taken."
    exit 0
fi

#------------------------------------------------------------------------------
# Extract reads from the specified chromosome
#------------------------------------------------------------------------------
echo "Extracting reads from chromosome '$chromosome' using $processors processor(s)..."
samtools view -@ "$processors" -b -h "$input_file" "$chromosome" > "$output_file"
if [ $? -ne 0 ]; then
    echo "Error: Failed to extract reads."
    exit 1
fi

#------------------------------------------------------------------------------
# Extraction completed message
#------------------------------------------------------------------------------
echo "Extraction completed. Generated file: '$output_file'"