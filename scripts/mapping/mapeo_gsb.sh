#!/bin/bash
set -euo pipefail

# --------------------------------------------------------------
# Descripción:
# Mapea lecturas de un individuo a una referencia usando Bowtie2
# y genera un BAM ordenado.
#
# Opciones:
#   --multimap K   -> bowtie2 -k K  (multi-mapping; por defecto K=3)
#   --unique       -> filtra y deja SOLO alineamientos "confiables"
#                    (MAPQ >= N y sin secundarios/suplementarios)
#   --mapq N       -> umbral MAPQ para --unique (por defecto 20)
#
# Si NO se pasan opciones, el script funciona como antes: -k 3.
# --------------------------------------------------------------


set -euo pipefail

usage() {
  cat <<EOF
Uso:
  $0 <individuo> <referencia.fasta> <workdir> <procesadores> [--multimap K] [--unique] [--mapq N]
EOF
}

if [ $# -lt 4 ]; then
  usage
  exit 1
fi

# Obligatorios
ind=$1
reference=$2
workdir=$3
proc=$4
shift 4

# Opcionales (defaults)
MULTIMAP_K=3
UNIQUE_MODE=0
UNIQUE_MAPQ=20

# Parseo de args
while [ $# -gt 0 ]; do
  case "$1" in
    --multimap)
      [ $# -ge 2 ] || { echo "ERROR: --multimap requiere K"; exit 1; }
      MULTIMAP_K="$2"
      shift 2
      ;;
    --unique)
      UNIQUE_MODE=1
      shift 1
      ;;
    --mapq)
      [ $# -ge 2 ] || { echo "ERROR: --mapq requiere N"; exit 1; }
      UNIQUE_MAPQ="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: argumento desconocido: $1"
      usage
      exit 1
      ;;
  esac
done

# Validaciones
if ! [[ "$MULTIMAP_K" =~ ^[0-9]+$ ]] || [ "$MULTIMAP_K" -lt 1 ]; then
  echo "ERROR: --multimap K debe ser entero >= 1. Recibido: $MULTIMAP_K"
  exit 1
fi

if ! [[ "$UNIQUE_MAPQ" =~ ^[0-9]+$ ]] || [ "$UNIQUE_MAPQ" -lt 0 ]; then
  echo "ERROR: --mapq N debe ser entero >= 0. Recibido: $UNIQUE_MAPQ"
  exit 1
fi

if [ "$UNIQUE_MODE" -eq 1 ] && [ "$MULTIMAP_K" -ne 3 ]; then
  echo "ERROR: --unique y --multimap no se deben usar juntos."
  exit 1
fi

# Read Group
s="SM:${ind}"

# FASTQ entrada
f1="/biodata1/HTS/GBS/demultiplexed_data/reads/${ind}_corrected.fastq.gz"

# Índice de referencia
directorio=$(dirname "$reference")
nombre_sin_extension=$(basename "$reference" .fasta)
INDEXES="${directorio}/${nombre_sin_extension}"

# Salida dentro de la carpeta indicada por el usuario, en subcarpeta gbs
output_dir="${workdir}/gbs/${nombre_sin_extension}"
output_bam="${output_dir}/${ind}_bowtie2_sorted.bam"

# Validaciones iniciales
if [ ! -f "$INDEXES.1.bt2" ] && [ ! -f "$INDEXES.1.bt2l" ]; then
  echo "ERROR: No se encontró índice Bowtie2: ${INDEXES}.1.bt2 ni ${INDEXES}.1.bt2l"
  exit 1
fi

if [ ! -f "$f1" ]; then
  echo "ERROR: FASTQ no encontrado: $f1"
  exit 2
fi

mkdir -p "$output_dir"
echo "Directorio de salida: $output_dir"

if [ -f "$output_bam" ]; then
  echo "BAM final ya existe: $output_bam"
  echo "Saltando."
  exit 0
fi

log_bowtie="${output_dir}/${ind}_bowtie2.log"
tmp_bam="${output_dir}/${ind}_bowtie2.tmp.bam"

echo "Mapeo en curso para ${ind}..."

if [ "$UNIQUE_MODE" -eq 1 ]; then
  echo "Modo: UNIQUE (filtrado MAPQ >= ${UNIQUE_MAPQ}, sin secundarios/suplementarios)"
  bowtie2 \
    -x "$INDEXES" \
    -U "$f1" \
    --rg-id "$ind" \
    --rg "$s" \
    --rg PL:ILLUMINA \
    -p "$proc" \
    -k 1 \
    -t \
    2> "$log_bowtie" \
    | samtools view -bh -q "$UNIQUE_MAPQ" -F 2304 - \
    > "$tmp_bam"
else
  echo "Modo: MULTIMAP (bowtie2 -k ${MULTIMAP_K})"
  bowtie2 \
    -x "$INDEXES" \
    -U "$f1" \
    --rg-id "$ind" \
    --rg "$s" \
    --rg PL:ILLUMINA \
    -p "$proc" \
    -k "$MULTIMAP_K" \
    -t \
    2> "$log_bowtie" \
    | samtools view -bh - \
    > "$tmp_bam"
fi

echo "Ordenando BAM..."
samtools sort "$tmp_bam" -o "$output_bam"
samtools index "$output_bam"

echo "QC (flagstat)..."
samtools flagstat "$output_bam" > "${output_dir}/${ind}_bowtie2_flagstat.log"

rm -f "$tmp_bam"
echo "Listo: $output_bam"