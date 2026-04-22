#!/bin/bash

# Usage: ./extract_genotypes.sh genotype_matrix.csv snp_list.txt [individual_list.txt]

INPUT_CSV=$1
SNP_LIST=$2
INDIVIDUAL_LIST=$3

if [[ ! -f "$INPUT_CSV" || ! -f "$SNP_LIST" ]]; then
    echo "Usage: $0 genotype_matrix.csv snp_list.txt [individual_list.txt]"
    exit 1
fi

# 1. Define column indexes
if [[ -f "$INDIVIDUAL_LIST" ]]; then
    # Get indexes for requested individuals (keeping column 1 - Marker)
    IND_PATTERN=$(tr -d '\r' < "$INDIVIDUAL_LIST" | paste -sd '|' -)
    COLUMN_IDXS=$(head -n 1 "$INPUT_CSV" | tr ',' '\n' | tr -d '\r' | nl -v 1 | \
          grep -E "^[[:space:]]+[0-9]+[[:space:]]+(Marker|($IND_PATTERN))$" | \
          awk '{print $1}' | tr '\n' ',')
else
    # If no individual list, use column 1 (Marker) and columns 6+ (Individuals)
    TOTAL_COLS=$(head -n 1 "$INPUT_CSV" | tr ',' '\n' | wc -l)
    COLUMN_IDXS="1,"$(seq -s, 6 $TOTAL_COLS)
fi

# Remove trailing comma if present
COLUMN_IDXS=$(echo $COLUMN_IDXS | sed 's/,$//')

# 2. Process with AWK
awk -F',' -v snps_file="$SNP_LIST" -v idxs_str="$COLUMN_IDXS" '
    BEGIN {
        # Load list of target SNPs
        while ((getline < snps_file) > 0) {
            gsub(/\r/, "", $0);
            if ($0 != "") snp_list[$0] = 1
        }
        # Convert index string into an array
        n_idx = split(idxs_str, target_cols, ",")
    }
    
    {
        # Get the marker prefix (e.g.: from 1_10058043_T_C, extract 1_10058043)
        # On the first line (NR==1), "prefix" will be "Marker"
        match($1, /^[0-9]+_[0-9]+/)
        prefix = (NR == 1) ? "Marker" : substr($1, RSTART, RLENGTH)

        # If it is the header OR the prefix is in our SNP list
        if (NR == 1 || prefix in snp_list) {
            for (i = 1; i <= n_idx; i++) {
                printf "%s%s", $target_cols[i], (i == n_idx ? "" : ",")
            }
            print ""
        }
    }
' "$INPUT_CSV"
