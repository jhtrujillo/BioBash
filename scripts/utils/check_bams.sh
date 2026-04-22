#!/bin/bash

###############################################################################
# Script: check_bams.sh
# Description: Check BAM files in a directory for readiness:
#              - indexed
#              - coordinate-sorted
#              - not empty
#              - valid headers
#              - summary stats
#
# Usage:
#   ./check_bams.sh /path/to/bam_folder
###############################################################################

# Check argument
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/bam_folder"
  exit 1
fi

BAM_DIR="$1"

# Create output report
REPORT="bam_qc_report_$(date +%Y%m%d_%H%M%S).txt"
echo "Checking BAM files in: $BAM_DIR" > "$REPORT"
echo "Report: $REPORT"
echo "==============================================" >> "$REPORT"

# Loop over BAM files
for bam in "$BAM_DIR"/*.bam; do
  echo "Checking: $(basename "$bam")" >> "$REPORT"

  # 1. Index check
  if [ -f "${bam}.bai" ]; then
    echo " - Index: OK (.bai found)" >> "$REPORT"
  else
    echo " - Index: MISSING" >> "$REPORT"
  fi

  # 2. Sort order check
  sort_order=$(samtools view -H "$bam" | grep '^@HD' | grep -o 'SO:[^[:space:]]*' | cut -d: -f2)
  if [ "$sort_order" = "coordinate" ]; then
    echo " - Sort order: coordinate" >> "$REPORT"
  else
    echo " - Sort order: $sort_order (Expected: coordinate)" >> "$REPORT"
  fi

  # 3. Read count check
  total_reads=$(samtools view -c "$bam")
  echo " - Total reads: $total_reads" >> "$REPORT"
  if [ "$total_reads" -eq 0 ]; then
    echo "   WARNING: BAM is empty" >> "$REPORT"
  fi

  # 4. Header check
  if samtools view -H "$bam" | grep -q '^@SQ'; then
    echo " - Header: OK (@SQ found)" >> "$REPORT"
   else
    echo " - Header: INVALID or missing" >> "$REPORT"
  fi
done

