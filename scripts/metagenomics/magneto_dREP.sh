#!/bin/bash

# ------------------------------------------------------------------
# Script: magneto_dREP.sh
# Description: Generates Mash sketches and runs dRep for
#              dereplication of genomic bins (MAGs).
#
# Usage:
#   ./magneto_dREP.sh -mashdb <mash_dir> -bins <bins_dir> -out <results_subdir> \
#                     [-p <threads>] [--completeness <val>] [--contamination <val>]
#
# Parameters:
#   -mashdb         Directory to store Mash files
#   -bins           Directory containing bin files (.fa)
#   -out            Subdirectory name for Mash and dRep results
#   -p              Number of threads (default: 40)
#   --completeness  Minimum bin completeness (default: 0.40)
#   --contamination Maximum allowed contamination (default: 15.0)
# ------------------------------------------------------------------

usage() {
    echo "Usage: $0 -mashdb <mash_dir> -bins <bins_dir> -out <subdir_name> [-p <threads>] [--completeness <val>] [--contamination <val>]"
    echo ""
    echo "Options:"
    echo "  -mashdb           Directory to save Mash files."
    echo "  -bins             Directory containing bin files (.fa)."
    echo "  -out              Subdirectory name for results."
    echo "  -p                Number of threads (default: 40)."
    echo "  --completeness    Minimum bin completeness (default: 0.40)."
    echo "  --contamination   Maximum allowed contamination (default: 15.0)."
    exit 1
}

# Defaults
threads=40
completeness=0.40
contamination=15.0

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -mashdb)       mash_db="$2";      shift ;;
        -bins)         bins="$2";          shift ;;
        -out)          output_name="$2";   shift ;;
        -p)            threads="$2";       shift ;;
        --completeness) completeness="$2"; shift ;;
        --contamination) contamination="$2"; shift ;;
        -h|--help)     usage ;;
        *) echo "Invalid option: $1" >&2; usage ;;
    esac
    shift
done

if [ -z "$mash_db" ] || [ -z "$bins" ] || [ -z "$output_name" ]; then
    echo "Error: Missing required parameters."
    usage
fi

# Activate Conda environment
conda activate bowtie_env_py310

# Create directories
mkdir -p "${mash_db}"
mkdir -p "${mash_db}/${output_name}"

# Generate Mash sketches
echo "Generating Mash sketch files..."
mash sketch -o "${mash_db}/${output_name}/${output_name}" "${bins}"/*.fa

# Run dRep dereplication
echo "Running dRep for bin dereplication..."
dRep dereplicate complete_only -g "${bins}"/*.fa --S_algorithm gANI

# Example with full parameters (uncomment and customize as needed):
# dRep dereplicate "dREP_all/" \
#   -p "$threads" \
#   --completeness "$completeness" \
#   --contamination "$contamination" \
#   -g "${bins}"/*.fa --S_algorithm gANI

if [ $? -ne 0 ]; then
    echo "Error: dRep execution failed."
    exit 1
fi

echo "dRep completed successfully. Results in: ${mash_db}/${output_name}/"
