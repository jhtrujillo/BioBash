#cript: compare_vcfs.sh
# Description: Verifies if all VCF files in a given directory
#              have the same sample order in the #CHROM line.
#
# Usage:
#     ./compare_vcfs.sh -d /path/to/vcf_directory
#
# Parameters:
#     -d    Path to the directory containing .vcf files
#
# Author: Inteligencia Artificial (Cenicaña)
# Date: May 14, 2025
#####################################################################

# Help function
show_help() {
	  echo "Usage: $0 -d <vcf_directory>"
	    exit 1
    }

    # Parse arguments
    while getopts "d:" opt; do
	      case $opt in
		          d) vcf_dir="$OPTARG" ;;
			      *) show_help ;;
			        esac
			done

			# Validate input
			if [ -z "$vcf_dir" ]; then
				  show_help
			  fi

			  # Check directory existence
			  if [ ! -d "$vcf_dir" ]; then
				    echo "Error: Directory '$vcf_dir' does not exist."
				      exit 1
			      fi

			      echo "Starting comparison in directory: $vcf_dir"

			      reference_header=""

			      for file in "$vcf_dir"/*.vcf; do
				        # Extract the #CHROM line and columns from sample 10 onwards
					  header=$(grep "^#CHROM" "$file" | cut -f10-)

					    if [ -z "$reference_header" ]; then
						        reference_header="$header"
							  else
								      if [ "$header" != "$reference_header" ]; then
									            echo "Mismatch found in file: $file"
										        fi
											  fi
										  done

										  echo "Comparison completed."

