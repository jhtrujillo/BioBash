#!/bin/bash

# ------------------------------------------------------------------
# Script: magneto_checkM.sh
# Description: Automates quality assessment of genome bins (MAGs)
#              using CheckM in 'lineage_wf' mode.
#
# Usage:
#   bash magneto_checkM.sh -f <bin_format> -i <bins_dir> -o <checkm_output> \
#                          -t <threads> -l <log_prefix>
#
# Example:
#   bash magneto_checkM.sh -f fa -i bins/ -o checkm_output/ -t 90 -l my_run
#
# Parameters:
#   -f    Bin file format (e.g., 'fa' or 'fasta')
#   -i    Input directory containing bin files
#   -o    Output directory for CheckM results
#   -t    Number of threads for CheckM
#   -l    Log file prefix. Log will be named <prefix>_checkm.txt
#   -h    Show this help message
# ------------------------------------------------------------------

BIN_FORMAT=""
INPUT_BIN_DIR=""
OUTPUT_CHECKM_DIR=""
THREADS=""
LOG_PREFIX=""

usage() {
    echo "Usage: $0 -f <bin_format> -i <bins_dir> -o <checkm_output> -t <threads> -l <log_prefix>"
    echo ""
    echo "Options:"
    echo "  -f    Bin file format (e.g., 'fa' or 'fasta')."
    echo "  -i    Input directory containing bin files."
    echo "  -o    Output directory for CheckM results."
    echo "  -t    Number of processor threads for CheckM."
    echo "  -l    Log file prefix. Output will be saved as <prefix>_checkm.txt."
    echo "  -h    Show this help message."
    exit 1
}

while getopts "f:i:o:t:l:h" opt; do
    case ${opt} in
        f) BIN_FORMAT=$OPTARG    ;;
        i) INPUT_BIN_DIR=$OPTARG ;;
        o) OUTPUT_CHECKM_DIR=$OPTARG ;;
        t) THREADS=$OPTARG       ;;
        l) LOG_PREFIX=$OPTARG    ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :)  echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done
shift $((OPTIND -1))

if [ -z "$BIN_FORMAT" ] || [ -z "$INPUT_BIN_DIR" ] || [ -z "$OUTPUT_CHECKM_DIR" ] || \
   [ -z "$THREADS" ] || [ -z "$LOG_PREFIX" ]; then
    echo "Error: Missing required parameters."
    usage
fi

echo "--- Starting CheckM bin quality assessment ---"
echo "Bin format:       $BIN_FORMAT"
echo "Input directory:  $INPUT_BIN_DIR"
echo "Output directory: $OUTPUT_CHECKM_DIR"
echo "Threads:          $THREADS"
echo "Log prefix:       $LOG_PREFIX"

# Activate Conda environment
echo "Activating Conda environment..."
eval "$(conda shell.bash hook)"
conda activate /biodata4/ambientes_conda/miniforge3/envs/bowtie_env_py310/

if [ $? -ne 0 ]; then
    echo "Error: Failed to activate Conda environment. Make sure it exists and conda is initialized."
    exit 1
fi
echo "Conda environment activated."

# Create output directory if needed
if [ ! -d "$OUTPUT_CHECKM_DIR" ]; then
    echo "Creating CheckM output directory: $OUTPUT_CHECKM_DIR"
    mkdir -p "$OUTPUT_CHECKM_DIR"
fi

# Set log file path
LOG_FILE="$OUTPUT_CHECKM_DIR/${LOG_PREFIX}_checkm.txt"
echo "CheckM output will be written to: $LOG_FILE"

# Run CheckM
echo "Running CheckM (lineage_wf mode)..."
checkm lineage_wf -x "$BIN_FORMAT" "$INPUT_BIN_DIR" "$OUTPUT_CHECKM_DIR" \
    -t "$THREADS" 1> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    echo "Error: CheckM execution failed. Check the log: $LOG_FILE"
    exit 1
fi

echo "CheckM completed. Results: $OUTPUT_CHECKM_DIR  Log: $LOG_FILE"
echo "--- CheckM workflow completed successfully ---"
