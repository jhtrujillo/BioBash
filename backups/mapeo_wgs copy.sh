#!/bin/bash
# --------------------------------------------------------------
# Script para mapear lecturas pareadas (WGS) con Bowtie2 + Samtools
# --------------------------------------------------------------
# Uso: ./mapeo_wgs.sh <individuo> <referencia> <workdir> <procesadores> [I=200] [X=400]
# Ejemplo:
# ./mapeo_wgs.sh IND01 /ruta/referencia.fasta /ruta/resultados 8
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
# Entradas y parámetros
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
# Buscar ID del individuo (WGS)
# --------------------------------------------------------------
idWGS=$(awk -v individuo="${ind}" '{if ($2==individuo) print $1}' /biodata2/HTS/WGS/consecutivosEI-Cenicana.txt || true)
if [ -z "${idWGS}" ]; then
  echo "ERROR: No se encontró el ID para el individuo '${ind}' en /biodata2/HTS/WGS/consecutivosEI-Cenicana.txt"
  exit 2
fi

# --------------------------------------------------------------
# Construir prefijo del índice de forma robusta
# --------------------------------------------------------------
directorio="$(dirname "$reference")"
base="$(basename "$reference")"
base="${base%.gz}"
base="${base%.fasta}"
base="${base%.fa}"
base="${base%.fna}"
INDEXES="${directorio}/${base}"

# --------------------------------------------------------------
# Preparar salida
# --------------------------------------------------------------
output_dir="${workdir}/${base}"
mkdir -p "$output_dir"

sorted_bam="${output_dir}/${ind}_sorted.bam"
log_bt2="${output_dir}/${ind}_bowtie2.log"

# --------------------------------------------------------------
# Validar índices (.bt2 o .bt2l)
# --------------------------------------------------------------
if [ ! -f "${INDEXES}.1.bt2" ] && [ ! -f "${INDEXES}.1.bt2l" ]; then
  echo "ERROR: No se encontró el índice Bowtie2 con prefijo:"
  echo "  ${INDEXES}"
  echo "Se esperaba encontrar:"
  echo "  ${INDEXES}.1.bt2  o  ${INDEXES}.1.bt2l"
  exit 3
fi

# --------------------------------------------------------------
# Rutas de entrada (lecturas)
# --------------------------------------------------------------
f1="/biodata2/HTS/WGS/${idWGS}/${idWGS}_R1.fastq.gz"
f2="/biodata2/HTS/WGS/${idWGS}/${idWGS}_R2.fastq.gz"

if [ ! -f "$f1" ] || [ ! -f "$f2" ]; then
  echo "ERROR: No se encontraron los archivos FASTQ esperados:"
  echo "  - $f1"
  echo "  - $f2"
  exit 4
fi

# --------------------------------------------------------------
# Evitar reprocesar si ya existe el BAM ordenado
# --------------------------------------------------------------
if [ -f "$sorted_bam" ]; then
  echo "El archivo BAM ordenado ya existe: $sorted_bam"
  echo "Se omite el proceso para ${ind}."
  exit 0
fi

echo "Directorio de trabajo: $output_dir"
echo "Índice Bowtie2 (prefijo): $INDEXES"
echo "Lecturas:"
echo "  R1: $f1"
echo "  R2: $f2"
echo "Comenzando mapeo + ordenamiento..."

# --------------------------------------------------------------
# Mapeo y ordenamiento directo a BAM ordenado
# --------------------------------------------------------------
bowtie2 --rg-id "${ind}" --rg "${s}" --rg PL:ILLUMINA \
  -I "${i}" -X "${x}" -p "${proc}" -k 3 -t \
  -x "${INDEXES}" -1 "${f1}" -2 "${f2}" 2> "${log_bt2}" \
| samtools view -bhS - \
| samtools sort -@ "${proc}" -o "${sorted_bam}"

echo "Mapeo y ordenamiento completados. BAM: $sorted_bam"

# --------------------------------------------------------------
# Validación BAM
# --------------------------------------------------------------
samtools flagstat "${sorted_bam}" > "${output_dir}/${ind}_sorted_flagstat.log"

if grep -q "in total" "${output_dir}/${ind}_sorted_flagstat.log"; then
  echo "Archivo BAM ordenado válido: ${sorted_bam}"
else
  echo "ADVERTENCIA: BAM posiblemente vacío o dañado. Revisa: ${output_dir}/${ind}_sorted_flagstat.log"
  exit 5
fi

echo "Proceso finalizado exitosamente para el individuo ${ind}."
