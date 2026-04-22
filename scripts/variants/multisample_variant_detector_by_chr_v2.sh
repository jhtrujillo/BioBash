#!/bin/bash

# --------------------------------------------------------------
# Script: multisamplevariantsdetectorbyChr.sh
# Author: Jhon Henry Trujillo Montenegro
# Date: April 22, 2025
# Description:
#   This script efficiently extracts reads for a specific chromosome
#   from multiple BAM or CRAM files located in a user-defined input
#   directory. It uses the 'find' command to locate these files and a
#   loop to process them sequentially. It calls an external script
#   ('/biodata4/proyectos/scripts/extraer_cromosoma_desde_bam.sh')
#   to perform chromosome extraction on each input file. The resulting
#   chromosome-specific files are saved in a temporary subdirectory,
#   which can be user-defined with -t, or otherwise is generated inside
#   the input directory with the chromosome name. Optionally, it can
#   execute a variant calling script and then clean up the temporary files.
#
# Usage:
#   ./multisamplevariantsdetectorbyChr.sh -d <dir> -c <chr> -p <procs> [--ploidy <ploidy>] -r <ref> -o <vcf> [-t <tmp_dir>]
#
# Example:
#   ./multisamplevariantsdetectorbyChr.sh -d all_bams -c chr2 -p 16 --ploidy 2 -r /path/to/ref.fasta -o variants/output_chr2.vcf
#   ./multisamplevariantsdetectorbyChr.sh -c 1 -d input_data -r ref.fasta -o results/final.vcf -t /tmp/chr1_tmp
# --------------------------------------------------------------

set -euo pipefail

# --- Function to display help message ---
show_help() {
    echo "Usage: $0 -d <input_dir> -c <chr> -p <procs> [--ploidy <ploidy>] -r <ref> -o <vcf> [-t <tmp_dir>]"
    echo ""
    echo "  -d          Input directory with BAM/CRAM files (required)."
    echo "  -c          Chromosome to extract (e.g., 'chr1', '2') (required)."
    echo "  -p          Number of processors to use. Default is 20."
    echo "  --ploidy    Ploidy level for variant calling. Default is 10."
    echo "  -r          Reference genome in FASTA format. Required for variant calling."
    echo "  -o          Output VCF file. Required for variant calling."
    echo "  -t          Base path for the temporary directory."
    echo "  -h, --help  Show this help message."
}


# --- Initialize variables and default values ---
input_data_directory=""
chromosome=""
processors=20
ploidy=10 # Default ploidy value
reference_fasta=""
vcf_output_file=""
temporary_directory=""

# --------------------------------------------------------------
# Parse command-line arguments manually to support long options
# --------------------------------------------------------------
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -d) input_data_directory="$2"; shift 2 ;;
        -c) chromosome="$2"; shift 2 ;;
        -p) processors="$2"; shift 2 ;;
        --ploidy) ploidy="$2"; shift 2 ;;
        -r) reference_fasta="$2"; shift 2 ;;
        -o) vcf_output_file="$2"; shift 2 ;;
        -t) temporary_directory="$2"; shift 2 ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown parameter passed: $1"
            show_help >&2
            exit 1
            ;;
    esac
done

# --------------------------------------------------------------
# Verify that the mandatory arguments for extraction have been provided
# --------------------------------------------------------------
if [ -z "$input_data_directory" ] || [ -z "$chromosome" ]; then
  echo "Error: The -d (input directory) and -c (chromosome) arguments are mandatory." >&2
  show_help >&2
  exit 1
fi

# --------------------------------------------------------------
# Validate that ploidy and processors are integers
# --------------------------------------------------------------
if ! [[ "$ploidy" =~ ^[0-9]+$ ]]; then
    echo "Error: Ploidy value (--ploidy) must be an integer. You provided: '$ploidy'" >&2
    exit 1
fi
if ! [[ "$processors" =~ ^[0-9]+$ ]]; then
    echo "Error: Processors value (-p) must be an integer. You provided: '$processors'" >&2
    exit 1
fi


# --------------------------------------------------------------
# Check if the output VCF file already exists
# --------------------------------------------------------------
if [ -n "$vcf_output_file" ] && [ -f "$vcf_output_file" ]; then
  echo "Warning: The output VCF file '$vcf_output_file' already exists. Skipping the entire process."
  exit 0
fi

# --------------------------------------------------------------
# Set default temporary directory if not provided
# --------------------------------------------------------------
# Set the full temporary directory path
if [ -z "$temporary_directory" ]; then
  temporary_directory="$input_data_directory/${chromosome}_extracted_temp"
else
  # Add the chromosome-specific suffix to the user-provided base path
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
if [ -n "$reference_fasta" ] && [ -n "$vcf_output_file" ]; then
  echo "Running the variant detector with ploidy $ploidy..."
  # Pass the ploidy value to the downstream script using its expected -p flag
  time /biodata4/proyectos/scripts/multisamplevariantsdetector.sh \
    -d "$temporary_directory" \
    -r "$reference_fasta" \
    -o "$vcf_output_file" \
    -p "$ploidy" # Note: This -p is for ploidy in the called script
  
  echo "Variant analysis completed. The VCF file has been saved as: $vcf_output_file"
elif [ -n "$reference_fasta" ] || [ -n "$vcf_output_file" ]; then
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
echo "Script finished successfully."
exit 0
