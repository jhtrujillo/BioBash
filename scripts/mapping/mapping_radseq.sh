#!/bin/bash
# --------------------------------------------------------------
# Script para mapear lecturas pareadas con Bowtie2 + Samtools (RADseq)
# --------------------------------------------------------------
# Uso: ./mapeo_radseq.sh <individuo> <referencia> <workdir> <procesadores> [I=200] [X=400]

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
# Construir prefijo del índice de forma robusta (igual idea que el anterior)
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
# Definir rutas de entrada y salida
# --------------------------------------------------------------
f1="/biodata1/HTS/RAD-Seq/F13TSFUSAT0280_SUGxtaR/Sequencing_data/${ind}_1.fq.gz"
f2="/biodata1/HTS/RAD-Seq/F13TSFUSAT0280_SUGxtaR/Sequencing_data/${ind}_2.fq.gz"

if [ ! -f "$f1" ] || [ ! -f "$f2" ]; then
    echo "ERROR: No se encontraron los archivos FASTQ esperados:"
    echo "  - $f1"
    echo "  - $f2"
    exit 4
fi

output_dir="${workdir}/${base}"
mkdir -p "$output_dir"
output_bam="${output_dir}/${ind}_sorted.bam"
log_bt2="${output_dir}/${ind}_bowtie2.log"

# --------------------------------------------------------------
# Evitar ejecución si el archivo BAM ya existe
# --------------------------------------------------------------
if [ -f "$output_bam" ]; then
    echo "El archivo BAM ordenado ya existe: $output_bam"
    echo "Se omite el proceso de mapeo para el individuo ${ind}."
    exit 0
fi

echo "Directorio de trabajo: $output_dir"
echo "Índice Bowtie2 (prefijo): $INDEXES"
echo "Comenzando mapeo y ordenamiento..."

# --------------------------------------------------------------
# Paso de mapeo y ordenamiento directo a BAM ordenado
# --------------------------------------------------------------
bowtie2 --rg-id "${ind}" --rg "${s}" --rg PL:ILLUMINA \
    -I "${i}" -X "${x}" -p "${proc}" -k 3 -t \
    -x "${INDEXES}" -1 "${f1}" -2 "${f2}" 2> "${log_bt2}" \
| samtools view -bhS - \
| samtools sort -@ "${proc}" -o "$output_bam"

echo "Mapeo y ordenamiento completados. BAM: $output_bam"

# --------------------------------------------------------------
# Validación del archivo BAM ordenado
# --------------------------------------------------------------
samtools flagstat "$output_bam" > "${output_dir}/${ind}_sorted_flagstat.log"

if grep -q "in total" "${output_dir}/${ind}_sorted_flagstat.log"; then
    echo "Archivo BAM ordenado válido: ${ind}_sorted.bam"
else
    echo "ADVERTENCIA: BAM posiblemente vacío o dañado. Revisa: ${output_dir}/${ind}_sorted_flagstat.log"
    exit 5
fi

echo "Proceso finalizado para el individuo ${ind}."
