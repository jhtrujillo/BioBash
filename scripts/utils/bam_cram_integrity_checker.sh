#!/bin/bash

# --------------------------------------------------------------------------
# Script: check_bam_cram_integrity.sh
# Author: Your AI Assistant
# Date: April 23, 2025
# Description:
#   This script checks the basic integrity of a single BAM or CRAM file.
#   It performs the following checks:
#     1. Verifies if the file exists.
#     2. Verifies if the file is not empty.
#     3. Attempts to read the header of the file using samtools.
#     4. Verifies if the corresponding index exists (for BAM files).
#     5. Performs a quick check of the file structure with samtools.
#
# Usage:
#   ./check_bam_cram_integrity.sh <path_to_file.bam_or_cram>
#
# Example:
#   ./check_bam_cram_integrity.sh sample.bam
#   ./check_bam_cram_integrity.sh aligned.cram
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Function to print error messages
# --------------------------------------------------------------------------
error_message() {
  echo "Error: $1" >&2
}

# --------------------------------------------------------------------------
# Verify if an argument (the file path) was provided
# --------------------------------------------------------------------------
if [ -z "$1" ]; then
  error_message "You must provide the path to the BAM or CRAM file."
  echo "Usage: $0 <path_to_file.bam_or_cram>" >&2
  exit 1
fi

file_path="$1"
file_name=$(basename "$file_path")

# --------------------------------------------------------------------------
# 1. Verify if the file exists
# --------------------------------------------------------------------------
if [ ! -f "$file_path" ]; then
  error_message "The file '$file_name' does not exist."
  exit 1
fi

echo "Checking file: '$file_name'"

# --------------------------------------------------------------------------
# 2. Verify if the file is not empty
# --------------------------------------------------------------------------
if [ -s "$file_path" ]; then
  echo "The file '$file_name' is not empty."
else
  error_message "The file '$file_name' is empty or has a size of 0 bytes."
  exit 1
fi

# --------------------------------------------------------------------------
# 3. Attempt to read the file header using samtools
# --------------------------------------------------------------------------
if command -v samtools >/dev/null 2>&1; then
  echo "Attempting to read the header with samtools..."
  if samtools view -H "$file_path" > /dev/null 2>&1; then
    echo "The header of the file '$file_name' appears to be valid."
  else
    error_message "Could not read or the header of the file '$file_name' appears corrupt."
    exit 1
  fi

  # --------------------------------------------------------------------------
  # 4. Verify if the corresponding index exists (for BAM files)
  # --------------------------------------------------------------------------
  if [[ "$file_name" == *.bam ]]; then
    index_file="${file_path}.bai"
    if [ ! -f "$index_file" ]; then
      echo "Warning: The BAM index file ('$index_file') was not found. A missing index can indicate an incomplete file or later issues."
    else
      echo "BAM index file found: '$index_file'."
    fi
  fi

  # --------------------------------------------------------------------------
  # 5. Perform a quick check of the file structure with samtools
  # --------------------------------------------------------------------------
  echo "Performing a quick check of the file structure with samtools..."
  if samtools quickcheck "$file_path" > /dev/null 2>&1; then
    echo "The structure of the file '$file_name' appears correct (according to samtools quickcheck)."
  else
    error_message "samtools quickcheck reported issues with the structure of the file '$file_name'."
    exit 1
  fi

else
  error_message "samtools is not installed or not in the PATH. More comprehensive checks cannot be performed."
  echo "Please ensure samtools is installed for a more thorough verification." >&2
fi

echo "The file '$file_name' passed basic integrity checks."
exit 0