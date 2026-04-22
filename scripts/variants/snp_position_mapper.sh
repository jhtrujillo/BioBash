#!/bin/bash

#------------------------------------------
# Script: SNP Position Mapper (with target chromosome output)
# Author: [Your Name]
#------------------------------------------

usage() {
  echo "Usage: $0 -chr <chromosome> -pos <position> -delta <window_size> -patron <pattern_size> -genome_query <source_genome.fasta> -db <target_genome_blast_db> -genome_target <target_genome.fasta>"
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -chr) chr="$2"; shift 2;;
    -pos) pos="$2"; shift 2;;
    -delta) delta="$2"; shift 2;;
    -patron) tamPatron="$2"; shift 2;;
    -genome_query) genomeQuery="$2"; shift 2;;
    -db) blastDb="$2"; shift 2;;
    -genome_target) genomeTarget="$2"; shift 2;;
    *) usage;;
  esac
done

if [ -z "$chr" ] || [ -z "$pos" ] || [ -z "$delta" ] || [ -z "$tamPatron" ] || [ -z "$genomeQuery" ] || [ -z "$blastDb" ] || [ -z "$genomeTarget" ]; then
  echo "Error: Missing parameters."
  usage
fi

if [ ! -f "$genomeQuery" ]; then
  echo "Error: Source genome '$genomeQuery' not found."
  exit 1
fi

if [ ! -f "$genomeTarget" ]; then
  echo "Error: Target genome '$genomeTarget' not found."
  exit 1
fi

if [ ! -f "$blastDb.nsq" ] && [ ! -f "$blastDb" ]; then
  echo "Error: BLAST database '$blastDb' not found or not indexed."
  exit 1
fi

# Calculate positions
posIniEnmas=$((pos-delta))
posFinEnmas=$((pos+delta))

posIniEnmasPatron=$((pos-tamPatron))
posFinEnmasPatron=$((pos+tamPatron))

# Extract pattern sequence
patron=$(samtools faidx "$genomeQuery" ${chr}:${posIniEnmasPatron}-${posFinEnmasPatron} | tail -n +2 | tr -d '\n' | sed 's/ //g')

if [ -z "$patron" ]; then
  echo "[ERROR] Pattern extraction failed."
  exit 1
fi

echo "[INFO] Pattern extracted: $patron"

# Extract wide region sequence from source genome
regionMaskedFile="${chr}_${posIniEnmas}-${posFinEnmas}.fan"
if ! samtools faidx "$genomeQuery" ${chr}:${posIniEnmas}-${posFinEnmas} > "$regionMaskedFile"; then
  echo "[ERROR] Failed to extract wide region from source genome."
  exit 1
fi

# Search pattern in wide region
if ! java -jar /biodata7/proyectos/posicionar_snps_enmarcarado_a_completo/biocenicana.jar rapidgenomic "$regionMaskedFile" "$patron"; then
  echo "[ERROR] Pattern search failed in source genome region."
  exit 1
fi

# Perform BLAST search
blastresult=$(blastn -num_threads 50 -dust no -reward 2 -penalty -3 -gapopen 5 -gapextend 2 -query "$regionMaskedFile" -db "$blastDb" -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore" | head -n1)

if [ -z "$blastresult" ]; then
  echo "[ERROR] No BLAST hit found."
  exit 1
fi

# Parse BLAST result
chrNoEnmas=$(echo "$blastresult" | awk '{print $2}')
posIniNoEnmasPatron=$(echo "$blastresult" | awk '{print $9}')
posFinNoEnmasPatron=$(echo "$blastresult" | awk '{print $10}')
porIdentity=$(echo "$blastresult" | awk '{print $3}')
missMatch=$(echo "$blastresult" | awk '{print $5}')
length=$(echo "$blastresult" | awk '{print $4}')
deltalength=$((length-missMatch))

# Extract sequence from target genome
regionNoMaskedFile="${chrNoEnmas}_${posIniNoEnmasPatron}-${posFinNoEnmasPatron}.fan"
if ! samtools faidx "$genomeTarget" ${chrNoEnmas}:${posIniNoEnmasPatron}-${posFinNoEnmasPatron} > "$regionNoMaskedFile"; then
  echo "[ERROR] Failed to extract region from target genome."
  exit 1
fi

# Search for pattern again in target genome
if ! java -jar /biodata7/proyectos/posicionar_snps_enmarcarado_a_completo/biocenicana.jar rapidgenomic "$regionNoMaskedFile" "$patron"; then
  echo "[ERROR] Pattern search failed in target genome region."
  exit 1
fi

posicionAlelosReferenciaNoEnmas=$(java -jar /biodata7/proyectos/posicionar_snps_enmarcarado_a_completo/biocenicana.jar rapidgenomic "$regionNoMaskedFile" "$patron" | head -n1 | sed "s/:/ /g" | awk '{print $3}')

# Extract reference alleles
refEnmas=$(samtools faidx "$genomeQuery" ${chr}:${pos}-${pos} | tail -n1)
refNoEnmas=$(samtools faidx "$genomeTarget" ${chrNoEnmas}:${posicionAlelosReferenciaNoEnmas}-${posicionAlelosReferenciaNoEnmas} | tail -n1)

# Print final results
echo "Final Result:"
echo "Source Chromosome: $chr"
echo "Original Position: $pos"
echo "Source Region: ${posIniEnmas}-${posFinEnmas}"
echo "Target Chromosome: $chrNoEnmas"
echo "Mapped New Position: ${posicionAlelosReferenciaNoEnmas}"
echo "BLAST Identity: $porIdentity%"
echo "Mismatch: $missMatch"
echo "Delta Length: $deltalength"
echo "Query Reference Allele: $refEnmas"
echo "Target Reference Allele: $refNoEnmas"
echo "Pattern Used: $patron"
echo $chr" "$pos" "$chrNoEnmas" "${posicionAlelosReferenciaNoEnmas}" "$porIdentity


# Clean temporary files
if [ -f "$regionMaskedFile" ] && [ -f "$regionNoMaskedFile" ]; then
  rm -f "$regionMaskedFile" "$regionNoMaskedFile"
  echo "[INFO] Temporary files removed."
else
  echo "[WARNING] Some temporary files were not found for cleanup."
fi

exit 0
