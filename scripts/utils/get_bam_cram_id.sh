#!/bin/bash

# --------------------------------------------------------------
# Script: get_bam_cram_id.sh
# Description:
#   Extracts the filename and sample ID from a BAM or CRAM file
#   (including CRAM compressed with .bz2) and prints the result
#   in the format: <filename> <sample_id>
#
# Usage:
#   ./get_bam_cram_id.sh <file.bam|file.cram|file.bz2>
# --------------------------------------------------------------

show_help() {
    echo "Usage: $0 <input.bam|input.cram|input.bz2>"
    exit 1
}

if [ $# -ne 1 ]; then
    echo "Error: You must provide a BAM or CRAM file."
    show_help
fi

input_file=$1

if [ ! -f "$input_file" ]; then
    echo "Error: File not found: $input_file"
    exit 2
fi

filename=$(basename "$input_file")

# If file is .bz2 (compressed CRAM), use bzcat to decompress on the fly
if [[ "$filename" == *.bz2 ]]; then
    sample_id=$(bzcat "$input_file" | samtools view -H - | grep "@RG" | \
        awk '{for(i=1;i<=NF;i++) if($i ~ /^ID:/) print $i}' | cut -d':' -f2)
else
    sample_id=$(samtools view -H "$input_file" | grep "@RG" | \
        awk '{for(i=1;i<=NF;i++) if($i ~ /^ID:/) print $i}' | cut -d':' -f2)
fi

if [ -z "$sample_id" ]; then
    echo "Error: Could not find sample ID in the file header."
    exit 3
fi

echo "$filename  $sample_id"
