#!/bin/bash

# --------------------------------------------------------------
# Script: multisamplevariantsdetectorbyChr.sh
# Author: Jhon Henry Trujillo Montenegro
# Date: April 22, 2025
# Description:
#    This script efficiently extracts reads for a specific chromosome
#    from multiple BAM or CRAM files located in a user-defined input
#    directory. It uses the 'find' command to locate these files and a
#    loop to process them sequentially. It calls an external script
#    ('/biodata4/proyectos/scripts/extraer_cromosoma_desde_bam.sh')
#    to perform chromosome extraction on each input file. The resulting
#    chromosome-specific files are saved in a temporary subdirectory,
#    which can be user-defined with -t, or otherwise is generated inside
#    the input directory with the chromosome name. Optionally, it can
#    execute a variant calling script and then clean up the temporary files.
#
# Usage:
#    ./multisamplevariantsdetectorbyChr.sh -d <input_data_directory> -c <chromosome> [-p <processors>] [-r <reference_fasta>] [-o <output_vcf_file>] [-t <temporary_directory>]
#
# Example:
#    ./multisamplevariantsdetectorbyChr.sh -d all_bams -c chr2 -p 16 -r /path/to/reference.fasta -o variants/output_chr2.vcf
#    ./multisamplevariantsdetectorbyChr.sh -c 1 -d input_data -r ref.fasta -o results/final.vcf -t /tmp/chr1_tmp
# --------------------------------------------------------------

set -euo pipefail

# --------------------------------------------------------------
# Define the options accepted by the script
# --------------------------------------------------------------
OPTS="d:c:p:r:o:t:"

# --------------------------------------------------------------
# Use getopt to parse the options and their arguments
# --------------------------------------------------------------
while getopts "$OPTS" opt; do
  case "$opt" in
    d) input_data_directory="$OPTARG" ;;
    c) chromosome="$OPTARG" ;;
    p) processors="$OPTARG" ;;
    r) reference_fasta="$OPTARG" ;;
    o) vcf_output_file="$OPTARG" ;;
    t) temporary_directory="$OPTARG" ;;
    \?) echo "Usage: $0 -d <input_data_directory> -c <chromosome> [-p <processors>] [-r <reference_fasta>] [-o <output_vcf_file>] [-t <temporary_directory>]" >&2; exit 1 ;;
  esac
done

# --------------------------------------------------------------
# Remove the processed options from the argument list
# --------------------------------------------------------------
shift $((OPTIND - 1))

# --------------------------------------------------------------
# Verify that the mandatory arguments for extraction have been provided
# --------------------------------------------------------------
if [ -z "${input_data_directory:-}" ] || [ -z "${chromosome:-}" ]; then
  echo "Error: The -d (input directory) and -c (chromosome) arguments are mandatory." >&2
  echo "Usage: $0 -d <input_data_directory> -c <chromosome> [-p <processors>] [-r <reference_fasta>] [-o <output_vcf_file>] [-t <temporary_directory>]" >&2
  exit 1
fi

# --------------------------------------------------------------
# Check if the output VCF file already exists
# --------------------------------------------------------------
if [ -n "${vcf_output_file:-}" ] && [ -f "$vcf_output_file" ]; then
  echo "Warning: The output VCF file '$vcf_output_file' already exists. Skipping the entire process."
  exit 0
fi

# --------------------------------------------------------------
# Set default value for the number of processors
# --------------------------------------------------------------
if [ -z "${processors:-}" ]; then
  processors=20
fi

# --------------------------------------------------------------
# Set default temporary directory if not provided
# --------------------------------------------------------------
# Set the full temporary directory path
if [ -z "${temporary_directory:-}" ]; then
  temporary_directory="$input_data_directory/${chromosome}_extracted_temp"
else
  # Agrega el sufijo al path base proporcionado con -t
  temporary_directory="${temporary_directory%/}/${chromosome}_temp"
fi


# --------------------------------------------------------------
# Create the temporary directory if it does not exist
# --------------------------------------------------------------
mkdir -p "$temporary_directory"

# --------------------------------------------------------------
# Find BAM/CRAM files and extract the chromosome using a while loop
# (robust to spaces in filenames)
# --------------------------------------------------------------
find "$input_data_directory" -maxdepth 1 -type f \( -name "*.bam" -o -name "*.cram" \) | while IFS= read -r bam_file; do
  echo "Extracting chromosome $chromosome from file: $bam_file using $processors processors."
  /biodata4/proyectos/scripts/extraer_cromosoma_desde_bam.sh -b "$bam_file" -c "$chromosome" -o "$temporary_directory" -p "$processors"
done

# --------------------------------------------------------------
# Completion message for extraction
# --------------------------------------------------------------
echo "Extraction completed. Chromosome $chromosome files have been temporarily saved in: $temporary_directory using $processors processors."

# --------------------------------------------------------------
# Execute the variant detector if -r and -o (for the VCF) options are provided
# --------------------------------------------------------------
if [ -n "${reference_fasta:-}" ] && [ -n "${vcf_output_file:-}" ]; then
  echo "Running the variant detector..."
  time /biodata4/proyectos/scripts/multisamplevariantsdetector.sh -d "$temporary_directory" -r "$reference_fasta" -o "$vcf_output_file"
  echo "Variant analysis completed. The VCF file has been saved as: $vcf_output_file"
elif [ -n "${reference_fasta:-}" ] || [ -n "${vcf_output_file:-}" ]; then
  echo "Warning: To run variant analysis, you must provide both -r (reference file) and -o (output VCF file path)."
fi

# --------------------------------------------------------------
# Delete the temporary directory
# --------------------------------------------------------------
if [ -d "$temporary_directory" ]; then
  echo "Deleting the temporary directory: $temporary_directory"
  rm -rf "$temporary_directory"
  echo "Temporary directory deleted."
fi

# --------------------------------------------------------------
# Exit the script
# --------------------------------------------------------------
exit 0
