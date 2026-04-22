#!/bin/bash
# --------------------------------------------------------------
# Script para mapear lecturas pareadas con Bowtie2 + Samtools
# --------------------------------------------------------------
# Uso: ./mapeo_pe.sh <individuo> <referencia> <workdir> <procesadores> [I=200] [X=400]
# --------------------------------------------------------------

set -euo pipefail

# --------------------------------------------------------------
# Validar número mínimo de argumentos
# --------------------------------------------------------------
if [ $# -lt 4 ]; then
  echo "USO: $0 <individuo> <referencia> <workdir> <procesadores> [I=200] [X=400]"
  exit 1
fi

# --------------------------------------------------------------
# Entradas desde línea de comandos
# --------------------------------------------------------------
ind="$1"
reference="$2"
workdir="$3"
proc="$4"
i="${5:-200}"
x="${6:-400}"
s="SM:${ind}"

# --------------------------------------------------------------
# Verificar referencia
# --------------------------------------------------------------
if [ ! -f "$reference" ]; then
  echo "ERROR: No existe la referencia: $reference"
  exit 2
fi

# --------------------------------------------------------------
# Construir prefijo del índice de forma robusta (igual que los otros)
# --------------------------------------------------------------
directorio="$(dirname "$reference")"
base="$(basename "$reference")"
base="${base%.gz}"
base="${base%.fasta}"
base="${base%.fa}"
base="${base%.fna}"
INDEXES="${directorio}/${base}"

# --------------------------------------------------------------
# Verificar índices de Bowtie2 (.bt2 o .bt2l)
# --------------------------------------------------------------
if [ ! -f "${INDEXES}.1.bt2" ] && [ ! -f "${INDEXES}.1.bt2l" ]; then
  echo "ERROR: No se encontró el índice Bowtie2 con prefijo:"
  echo "  ${INDEXES}"
  echo "Se esperaba encontrar:"
  echo "  ${INDEXES}.1.bt2  o  ${INDEXES}.1.bt2l"
  exit 3
fi

# --------------------------------------------------------------
# Definir rutas de entrada (seleccionar FASTQ más grande que cumpla patrón)
# --------------------------------------------------------------
data_dir="/biodata3/HTS/parentalesElite/${ind}"

if [ ! -d "$data_dir" ]; then
  echo "ERROR: No existe el directorio de datos: $data_dir"
  exit 4
fi

# Buscar candidatos R1/R2 (corrected tiene prioridad si es el más grande)
mapfile -t r1_candidates < <(find "$data_dir" -maxdepth 1 -type f \( -name "*_1_corrected.fq.gz" -o -name "*_1.fq.gz" \) -printf "%s\t%p\n" | sort -nr)
mapfile -t r2_candidates < <(find "$data_dir" -maxdepth 1 -type f \( -name "*_2_corrected.fq.gz" -o -name "*_2.fq.gz" \) -printf "%s\t%p\n" | sort -nr)

if [ ${#r1_candidates[@]} -eq 0 ] || [ ${#r2_candidates[@]} -eq 0 ]; then
  echo "ERROR: No se encontraron FASTQ pareados en: $data_dir"
  echo "Se esperaban patrones: *_1_corrected.fq.gz / *_1.fq.gz y *_2_corrected.fq.gz / *_2.fq.gz"
  exit 4
fi

f1="$(echo "${r1_candidates[0]}" | awk -F'\t' '{print $2}')"
f2="$(echo "${r2_candidates[0]}" | awk -F'\t' '{print $2}')"

if [ ! -f "$f1" ] || [ ! -f "$f2" ]; then
  echo "ERROR: No se encontraron los archivos FASTQ esperados:"
  echo "  - $f1"
  echo "  - $f2"
  exit 4
fi

# --------------------------------------------------------------
# Definir salida
# --------------------------------------------------------------
output_dir="${workdir}/${base}"
mkdir -p "$output_dir"

output_bam="${output_dir}/${ind}_sorted.bam"
log_bt2="${output_dir}/${ind}_bowtie2.log"

# --------------------------------------------------------------
# Evitar reprocesar si ya existe el BAM ordenado
# --------------------------------------------------------------
if [ -f "$output_bam" ]; then
  echo "El archivo BAM ordenado ya existe: $output_bam"
  echo "Se omite el proceso de mapeo para el individuo ${ind}."
  exit 0
fi

echo "Directorio de trabajo: $output_dir"
echo "Índice Bowtie2 (prefijo): $INDEXES"
echo "Lecturas:"
echo "  R1: $f1"
echo "  R2: $f2"
echo "Comenzando mapeo + ordenamiento..."

# --------------------------------------------------------------
# Mapeo y ordenamiento directo (más robusto)
# --------------------------------------------------------------
bowtie2 --rg-id "${ind}" --rg "${s}" --rg PL:ILLUMINA \
  -I "${i}" -X "${x}" -p "${proc}" -k 3 -t \
  -x "${INDEXES}" -1 "${f1}" -2 "${f2}" 2> "${log_bt2}" \
| samtools view -bhS - \
| samtools sort -@ "${proc}" -o "$output_bam"

echo "Mapeo y ordenamiento completados. BAM: $output_bam"

# --------------------------------------------------------------
# Validación del BAM ordenado
# --------------------------------------------------------------
samtools flagstat "$output_bam" > "${output_dir}/${ind}_sorted_flagstat.log"

if grep -q "in total" "${output_dir}/${ind}_sorted_flagstat.log"; then
  echo "Archivo BAM ordenado válido: ${ind}_sorted.bam"
else
  echo "ADVERTENCIA: Archivo BAM posiblemente vacío o dañado. Revisa: ${output_dir}/${ind}_sorted_flagstat.log"
  exit 5
fi

echo "Proceso finalizado para el individuo ${ind}."
