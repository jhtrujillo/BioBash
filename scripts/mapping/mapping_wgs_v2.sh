#!/bin/bash

# --------------------------------------------------------------
# Script: mapeo_wgs.sh
# Author: Jhon Henry Trujillo Montenegro
# Date: April 22, 2025
# Description:
#    This script maps paired-end reads using Bowtie2 and Samtools.
#    It takes FASTQ files as input, performs alignment using Bowtie2,
#    sorts the resulting BAM file, and validates the output. It also
#    provides the option to overwrite existing BAM files if the
#    parameter -f is passed for the reference file and -o for the output directory.
#
# Usage:
#    ./mapeo_wgs.sh -f <reference.fasta> -o <output_directory> -p <processors> <individual_id> [I=200] [X=400] [-f]
# Example:
#    ./mapeo_wgs.sh -f /path/to/reference.fasta -o /path/to/output -p 8 IND01
#    ./mapeo_wgs.sh -f /path/to/reference.fasta -o /path/to/output -p 8 IND01 -I 300 -X 500
# --------------------------------------------------------------

# --------------------------------------------------------------
# Validate minimum number of arguments
# --------------------------------------------------------------
if [ $# -lt 4 ]; then
    echo "USAGE: $0 -f <reference.fasta> -o <output_directory> -p <processors> <individual_id> [I=200] [X=400] [-f]"
    exit 1
fi

# --------------------------------------------------------------
# Inputs and parameters
# --------------------------------------------------------------
while getopts "f:o:p:I:X:" opt; do
    case "$opt" in
        f) reference="$OPTARG" ;;      # -f is used for the reference file
        o) output_dir="$OPTARG" ;;      # -o is used for the output directory
        p) proc="$OPTARG" ;;            # -p is used for the processors
        I) i="$OPTARG" ;;               # -I is used for the insert size
        X) x="$OPTARG" ;;               # -X is used for the maximum insert size
        \?) echo "Usage: $0 -f <reference.fasta> -o <output_directory> -p <processors> <individual_id> [I=200] [X=400] [-f]" >&2; exit 1 ;;
    esac
done

# Set default values for insert size and max insert size if not provided
i=${i:-200}
x=${x:-400}
proc=${proc:-1}  # Default value for processors is 1 if not provided

# Shift to remove the processed arguments
shift $((OPTIND - 1))

# Get individual ID from the remaining arguments
ind=$1
s="SM:${ind}"

# --------------------------------------------------------------
# Search for the individual ID in the database
# --------------------------------------------------------------
idWGS=$(awk -v individuo="${ind}" '{if ($2==individuo) print $1}' /biodata2/HTS/WGS/consecutivosEI-Cenicana.txt)
if [ -z "$idWGS" ]; then
    echo "ERROR: Individual ID '${ind}' not found in the database."
    exit 2
fi

# --------------------------------------------------------------
# Prepare paths and validate Bowtie2 indexes
# --------------------------------------------------------------
directorio=$(dirname "$reference")
nombre_sin_extension=$(basename "$reference" .fasta)
INDEXES="${directorio}/${nombre_sin_extension}"
unsorted_bam="${output_dir}/${ind}.bam"
sorted_bam="${output_dir}/${ind}_sorted.bam"

if [ ! -f "${INDEXES}.1.bt2" ]; then
    echo "ERROR: Bowtie2 index for the reference not found at ${INDEXES}. Please generate the index first."
    exit 1
fi

# --------------------------------------------------------------
# Input paths (FASTQ files)
# --------------------------------------------------------------
f1="/biodata2/HTS/WGS/${idWGS}/${idWGS}_R1.fastq.gz"
f2="/biodata2/HTS/WGS/${idWGS}/${idWGS}_R2.fastq.gz"

if [ ! -f "$f1" ] || [ ! -f "$f2" ]; then
    echo "ERROR: FASTQ files not found:"
    echo "  - $f1"
    echo "  - $f2"
    exit 4
fi

# Create output directory if it doesn't exist
mkdir -p "$output_dir"
echo "Working directory created: $output_dir"

# --------------------------------------------------------------
# Check if BAM files already exist
# --------------------------------------------------------------
if [ -f "$sorted_bam" ]; then
    echo "The sorted BAM file already exists: $sorted_bam"
    echo "Skipping mapping and sorting for ${ind}."
    exit 0
fi

if [ -f "$unsorted_bam" ]; then
    echo "The unsorted BAM file already exists: $unsorted_bam"
    echo "Skipping mapping and sorting for ${ind}."
    exit 0
fi

# --------------------------------------------------------------
# Run Bowtie2 mapping
# --------------------------------------------------------------
echo "Starting mapping..."

bowtie2 --rg-id "$ind" --rg "$s" --rg PL:ILLUMINA \
    -I "$i" -X "$x" -p "$proc" -k 3 -t \
    -x "$INDEXES" -1 "$f1" -2 "$f2" \
    2> "${output_dir}/${ind}_bowtie2.log" \
    | samtools view -bhS -o "$unsorted_bam"

if [ $? -ne 0 ]; then
    echo "ERROR: Mapping failed. Please check the log: ${output_dir}/${ind}_bowtie2.log"
    exit 3
fi

# --------------------------------------------------------------
# Sort the BAM file
# --------------------------------------------------------------
echo "Sorting BAM file..."
samtools sort -@ "$proc" -o "$sorted_bam" "$unsorted_bam"

if [ $? -ne 0 ]; then
    echo "ERROR: Sorting BAM file failed."
    exit 3
fi

# --------------------------------------------------------------
# Validate the sorted BAM file
# --------------------------------------------------------------
samtools flagstat "$sorted_bam" > "${output_dir}/${ind}_sorted_flagstat.log"

if grep -q "in total" "${output_dir}/${ind}_sorted_flagstat.log"; then
    echo "Sorted BAM file is valid: ${ind}_sorted.bam"
    rm -f "$unsorted_bam"
    echo "Unsorted BAM file removed: ${unsorted_bam}"
else
    echo "WARNING: The sorted BAM file may be empty or corrupted. Please check: ${output_dir}/${ind}_sorted_flagstat.log"
    exit 5
fi

echo "Process completed successfully for individual ${ind}."
