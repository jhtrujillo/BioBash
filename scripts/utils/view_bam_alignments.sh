#!/bin/bash

##########################################################################
# Script Name: view_bam_alignments.sh
#
# Description:
#   This script opens a BAM file using samtools tview to visualize aligned
#   sequencing reads over a reference genome directly in the terminal.
#
# Features:
#   - Accepts a BAM file (-b) [mandatory].
#   - Optionally accepts a custom reference genome FASTA file (-r).
#   - Optionally accepts a starting position (-s) to jump directly.
#   - If no reference is provided, a default reference is used.
#
# Usage:
#   ./view_bam_alignments.sh -b input.bam [-r reference.fasta] [-s chr:start]
#
# Example:
#   ./view_bam_alignments.sh -b CC21_sorted.bam
#   ./view_bam_alignments.sh -b CC21_sorted.bam -r new_reference.fasta
#   ./view_bam_alignments.sh -b CC21_sorted.bam -s chr2:100000
#
# Requirements:
#   - samtools installed and available in the system PATH.
#   - BAM file must be indexed (.bam.bai).
#   - Reference FASTA file must exist if specified.
##########################################################################

# ----------------------------
# Default Variables
# ----------------------------
BAM=""
REFERENCE="/biodata7/proyectos/ensamblajeCC01-1940/v2/genoma_enmascarado/cc-01-1940_flye_polishing_allhic_ngsepBuilder_enmascarado.fasta"
START=""

# ----------------------------
# Functions
# ----------------------------
usage() {
  echo ""
  echo "Usage: $0 -b input.bam [-r reference.fasta] [-s chr:start]"
  echo ""
  echo "Options:"
  echo "  -b   BAM file to visualize (mandatory)"
  echo "  -r   Reference genome FASTA file (optional)"
  echo "  -s   Start position (optional), e.g., chr1:10000"
  echo ""
  exit 1
}

# ----------------------------
# Parse Command-Line Options
# ----------------------------
while getopts ":b:r:s:" opt; do
  case ${opt} in
    b )
      BAM=$OPTARG
      ;;
    r )
      REFERENCE=$OPTARG
      ;;
    s )
      START=$OPTARG
      ;;
    \? )
      usage
      ;;
  esac
done

# ----------------------------
# Validation
# ----------------------------

# Check if BAM file was provided
if [ -z "$BAM" ]; then
  echo "Error: You must specify a BAM file with -b option."
  usage
fi

# Check if BAM file exists
if [ ! -f "$BAM" ]; then
  echo "Error: BAM file '$BAM' does not exist."
  exit 2
fi

# Check if reference file exists
if [ ! -f "$REFERENCE" ]; then
  echo "Error: Reference file '$REFERENCE' does not exist."
  exit 3
fi

# ----------------------------
# Main Execution
# ----------------------------

if [ -n "$START" ]; then
  echo "Opening samtools tview at position $START..."
  samtools tview "$BAM" "$REFERENCE" <<< "g $START"
else
  echo "Opening samtools tview from the beginning of the BAM file..."
  samtools tview "$BAM" "$REFERENCE"
fi

# End of script
##########################################################################

