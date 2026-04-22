#!/bin/bash

# ------------------------------------------------------------------
# Script: decompress.sh
# Description: Decompresses .gz and .bz2 files found in a directory
#              or decompresses a single specified file.
#
# Usage:
#   ./decompress.sh -i <input_dir_or_file> [-o <output_dir>]
#
# Options:
#   -i    Input file or directory containing compressed files (required)
#   -o    Output directory (default: same as input)
# ------------------------------------------------------------------

show_usage() {
    echo "Usage: $0 -i <input_dir_or_file> [-o <output_dir>]"
    echo "  -i    Input file or directory with compressed files (.gz or .bz2)"
    echo "  -o    Output directory (default: same location as input)"
    exit 1
}

output_dir=""

while getopts ":i:o:" opt; do
  case $opt in
    i) input="$OPTARG" ;;
    o) output_dir="$OPTARG" ;;
    *) show_usage ;;
  esac
done

if [ -z "${input:-}" ]; then
    show_usage
fi

if [ ! -e "$input" ]; then
    echo "Error: Input '$input' does not exist."
    exit 1
fi

decompress_file() {
    local file="$1"
    local dest_dir="${output_dir:-$(dirname "$file")}"
    mkdir -p "$dest_dir"

    local filename
    filename=$(basename "$file")

    if [[ "$file" == *.gz ]]; then
        echo "Decompressing (gzip): $file"
        gunzip -c "$file" > "${dest_dir}/${filename%.gz}"
    elif [[ "$file" == *.bz2 ]]; then
        echo "Decompressing (bzip2): $file"
        bunzip2 -c "$file" > "${dest_dir}/${filename%.bz2}"
    else
        echo "Skipping (unsupported format): $file"
    fi
}

if [ -f "$input" ]; then
    decompress_file "$input"
elif [ -d "$input" ]; then
    found=0
    for f in "$input"/*.gz "$input"/*.bz2; do
        [ -f "$f" ] || continue
        decompress_file "$f"
        found=1
    done
    if [ $found -eq 0 ]; then
        echo "No .gz or .bz2 files found in '$input'."
    fi
fi

echo "Decompression complete."
