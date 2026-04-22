#!/bin/bash

# ------------------------------------------------------------------------------
# Script: generate_bai_if_missing.sh
# Description:
#   Receives a BAM file with -b and the number of threads with -p (optional).
#   If the .bai index file does not exist, it generates it in the same location.
# ------------------------------------------------------------------------------

function usage {
    echo "Usage: $0 -b <input.bam> [-p <threads>]"
    echo "Example: $0 -b /path/to/sample.bam -p 8"
    exit 1
}

# Verify samtools is installed
if ! command -v samtools &>/dev/null; then
    echo "Error: samtools is not installed or not in the PATH."
    exit 1
fi

# Defaults
threads=4

# Parse arguments
while getopts ":b:p:" opt; do
  case $opt in
    b) bam_file="$OPTARG" ;;
    p) threads="$OPTARG" ;;
    *) usage ;;
  esac
done

if [ -z "${bam_file:-}" ]; then
    usage
fi

if [ ! -f "$bam_file" ]; then
    echo "Error: File '$bam_file' does not exist."
    exit 1
fi

# Get absolute path of BAM
bam_file_abs="$(readlink -f "$bam_file")"
bam_name="$(basename "$bam_file_abs")"
bai_file="$bam_file_abs.bai"

# Check and create index if missing
if [ -f "$bai_file" ]; then
    echo "Index file already exists: $bai_file"
else
    echo "Generating index for '$bam_name' using $threads thread(s)..."
    samtools index -@ "$threads" "$bam_file_abs"
    if [ $? -eq 0 ]; then
        echo "Index generated successfully: $bai_file"
    else
        echo "Error: Failed to generate index."
        exit 1
    fi
fi
