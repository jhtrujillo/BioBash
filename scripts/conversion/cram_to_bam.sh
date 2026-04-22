#!/bin/bash

# --------------------------------------------------------------
# Script: cram_to_bam.sh
# Description:
#   Converts a CRAM file to BAM format using samtools.
#   Checks if the output BAM file already exists; if so,
#   it does nothing. Allows specifying the number of threads and
#   an option to keep or remove the original CRAM file.
#
# Usage:
#   ./cram_to_bam.sh -c <input_file.cram> -o <output_file.bam> [-t <threads>] [-r|--remove-cram]
# --------------------------------------------------------------

# Default values
threads=1
remove_cram=false

# Parse options using getopt
PARSED_OPTIONS=$(getopt -n "$0" -o c:o:t:r --long remove-cram -- "$@")
if [ $? -ne 0 ]; then
  echo "Error parsing options." >&2
  exit 1
fi
eval set -- "$PARSED_OPTIONS"

# Extract options and their arguments
while true; do
  case "$1" in
    -c)
      input_cram="$2"
      shift 2
      ;;
    -o)
      output_bam="$2"
      shift 2
      ;;
    -t)
      threads="$2"
      shift 2
      ;;
    -r|--remove-cram)
      remove_cram=true
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$input_cram" ] || [ -z "$output_bam" ]; then
  echo "Error: Parameters -c (input CRAM file) and -o (output BAM file) are required." >&2
  echo "Usage: $0 -c <input_file.cram> -o <output_file.bam> [-t <threads>] [-r|--remove-cram]" >&2
  exit 1
fi

# Check if the input CRAM file exists and is readable
if [ ! -f "$input_cram" ] || [ ! -r "$input_cram" ]; then
  echo "Error: Input CRAM file '$input_cram' does not exist or cannot be read." >&2
  exit 1
fi

# Check if the output filename ends with .bam
if [[ "$output_bam" != *.bam ]]; then
  echo "Error: The output filename (-o) must end with the '.bam' extension." >&2
  echo "You provided: '$output_bam'" >&2
  exit 1
fi

# Validate threads argument (must be a positive integer)
if ! [[ "$threads" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: Number of threads (-t) must be a positive integer. You provided: '$threads'" >&2
  exit 1
fi

# Check if the output BAM file already exists
if [ -f "$output_bam" ]; then
  echo "Info: Output BAM file '$output_bam' already exists."
  echo "No action will be taken."
  exit 0
fi

# Check if the output directory exists, if not, create it
output_dir=$(dirname "$output_bam")
if [ ! -d "$output_dir" ]; then
  echo "Info: Creating output directory '$output_dir'..."
  mkdir -p "$output_dir"
  if [ $? -ne 0 ]; then
    echo "Error: Could not create output directory '$output_dir'." >&2
    exit 1
  fi
fi

# Execute the conversion using samtools
echo "Converting '$input_cram' to '$output_bam' using $threads thread(s)..."

# Note: CRAM decoding might require a reference genome (-T reference.fasta).
# If your CRAM requires it, you must add the -T option to the samtools view command.
# Example: samtools view -@ "$threads" -b -T /path/to/reference.fasta -o "$output_bam" "$input_cram"

samtools view -@ "$threads" -b -o "$output_bam" "$input_cram"
exit_code=$?

# Check if samtools was successful
if [ $exit_code -eq 0 ]; then
  echo "Conversion completed successfully."
  echo "BAM file saved at: $output_bam"
  # Remove the original CRAM file if the -r option was used
  if [ "$remove_cram" = true ]; then
    echo "Info: Removing original CRAM file '$input_cram'."
    rm "$input_cram"
    if [ $? -ne 0 ]; then
      echo "Warning: Could not remove the original CRAM file '$input_cram'." >&2
    fi
  fi
else
  echo "Error: samtools conversion failed (exit code: $exit_code)." >&2
  exit $exit_code
fi

exit 0
