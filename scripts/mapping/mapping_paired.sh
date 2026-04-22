#!/bin/bash
# --------------------------------------------------------------
# Script para mapear lecturas pareadas con Bowtie2 + Samtools
# Robusto para HPC: controla memoria/tmp de samtools sort
# --------------------------------------------------------------
# Uso:
# ./mapeo_pareado.sh <R1.fastq.gz> <R2.fastq.gz> <referencia> <workdir> <procesadores> [I=200] [X=400] [sample_name]
#
# Ejemplo:
# ./mapeo_pareado.sh muestra_R1.fastq.gz muestra_R2.fastq.gz /ruta/ref.fasta /ruta/resultados 32
#
# Parámetros:
#   R1.fastq.gz   : archivo forward
#   R2.fastq.gz   : archivo reverse
#   referencia    : genoma de referencia en fasta
#   workdir       : directorio de salida
#   procesadores  : número de hilos para Bowtie2
#   I             : tamaño mínimo de inserto (opcional, default=200)
#   X             : tamaño máximo de inserto (opcional, default=400)
#   sample_name   : nombre de muestra para read group (opcional)
# --------------------------------------------------------------

set -euo pipefail

# --------------------------------------------------------------
# Validar número mínimo de argumentos
# --------------------------------------------------------------
if [ $# -lt 5 ]; then
  echo "USO: $0 <R1.fastq.gz> <R2.fastq.gz> <referencia> <workdir> <procesadores> [I=200] [X=400] [sample_name]"
  exit 1
fi

# --------------------------------------------------------------
# Entradas y parámetros
# --------------------------------------------------------------
f1="$1"
f2="$2"
reference="$3"
workdir="$4"
proc="$5"
i="${6:-200}"
x="${7:-400}"
sample_name="${8:-}"

# --------------------------------------------------------------
# Verificar archivos de entrada
# --------------------------------------------------------------
if [ ! -f "$f1" ]; then
  echo "ERROR: No existe el archivo R1: $f1"
  exit 2
fi

if [ ! -f "$f2" ]; then
  echo "ERROR: No existe el archivo R2: $f2"
  exit 2
fi

if [ ! -f "$reference" ]; then
  echo "ERROR: No existe la referencia: $reference"
  exit 2
fi

# --------------------------------------------------------------
# Derivar nombre de muestra si no fue suministrado
# --------------------------------------------------------------
if [ -z "$sample_name" ]; then
  sample_name="$(basename "$f1")"
  sample_name="${sample_name%.fastq.gz}"
  sample_name="${sample_name%.fq.gz}"
  sample_name="${sample_name%.fastq}"
  sample_name="${sample_name%.fq}"
  sample_name="${sample_name%_R1}"
  sample_name="${sample_name%_1}"
fi

s="SM:${sample_name}"

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
output_dir="${workdir}/${sample_name}_${base}"
mkdir -p "$output_dir"

sorted_bam="${output_dir}/${sample_name}_sorted.bam"
log_bt2="${output_dir}/${sample_name}_bowtie2.log"

# --------------------------------------------------------------
# Validar índices (.bt2 o .bt2l)
# --------------------------------------------------------------
if [ ! -f "${INDEXES}.1.bt2" ] && [ ! -f "${INDEXES}.1.bt2l" ]; then
  echo "ERROR: No se encontró el índice Bowtie2 con prefijo:"
  echo "  ${INDEXES}"
  echo "Se esperaba encontrar:"
  echo "  ${INDEXES}.1.bt2  o  ${INDEXES}.1.bt2l"
  echo ""
  echo "Genera el índice con:"
  echo "  bowtie2-build ${reference} ${INDEXES}"
  exit 3
fi

# --------------------------------------------------------------
# Evitar reprocesar si ya existe el BAM ordenado
# --------------------------------------------------------------
if [ -f "$sorted_bam" ]; then
  echo "El archivo BAM ordenado ya existe: $sorted_bam"
  echo "Se omite el proceso para ${sample_name}."
  exit 0
fi

echo "Directorio de trabajo: $output_dir"
echo "Muestra: $sample_name"
echo "Índice Bowtie2 (prefijo): $INDEXES"
echo "Lecturas:"
echo "  R1: $f1"
echo "  R2: $f2"

# --------------------------------------------------------------
# Ajustes robustos para samtools sort
# --------------------------------------------------------------
tmp_root="${TMPDIR:-${output_dir}/tmp}"
tmp_dir="${tmp_root}/${sample_name}_samtools_tmp"
mkdir -p "$tmp_dir"

ulimit -n 65535 2>/dev/null || true

# RAM disponible (MemAvailable) en GiB
mem_avail_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo "")
if [[ -n "$mem_avail_kb" ]]; then
  mem_avail_gb=$(( mem_avail_kb / 1024 / 1024 ))
else
  mem_avail_gb=$(free -g 2>/dev/null | awk '/^Mem:/ {print $7}' || echo 0)
fi

# Hilos para sort (tope 32, mínimo 4)
sort_threads="$proc"
if (( sort_threads > 32 )); then sort_threads=32; fi
if (( sort_threads < 4 )); then sort_threads=4; fi

# Memoria por hilo para sort
if (( mem_avail_gb <= 0 )); then
  sort_mem="2G"
else
  total_for_sort=$(( mem_avail_gb * 70 / 100 ))
  per_thread=$(( total_for_sort / sort_threads ))
  if (( per_thread < 1 )); then per_thread=1; fi
  if (( per_thread > 4 )); then per_thread=4; fi
  sort_mem="${per_thread}G"
fi

echo "Ajustes samtools sort:"
echo "  sort_threads=${sort_threads}"
echo "  sort_mem=${sort_mem}"
echo "  tmp_dir=${tmp_dir}"
echo "  ulimit -n=$(ulimit -n 2>/dev/null || echo 'NA')"

echo "Comenzando mapeo + ordenamiento (BAM intermedio para máxima estabilidad)..."

# --------------------------------------------------------------
# Estrategia estable: BAM intermedio + sort
# --------------------------------------------------------------
unsorted_bam="${output_dir}/${sample_name}.bam"

# 1) Mapeo -> BAM sin ordenar
bowtie2 \
  --rg-id "${sample_name}" \
  --rg "${s}" \
  --rg PL:ILLUMINA \
  -I "${i}" \
  -X "${x}" \
  -p "${proc}" \
  -k 3 \
  -t \
  -x "${INDEXES}" \
  -1 "${f1}" \
  -2 "${f2}" \
  2> "${log_bt2}" \
| samtools view -bhS -o "${unsorted_bam}" -

# 2) Ordenar BAM
samtools sort \
  -@ "${sort_threads}" \
  -m "${sort_mem}" \
  -T "${tmp_dir}/${sample_name}.tmp" \
  -o "${sorted_bam}" \
  "${unsorted_bam}"

# 3) Limpiar BAM intermedio
rm -f "${unsorted_bam}"

echo "Mapeo y ordenamiento completados. BAM: $sorted_bam"

# --------------------------------------------------------------
# Indexar BAM
# --------------------------------------------------------------
samtools index -@ "${sort_threads}" "${sorted_bam}"

# --------------------------------------------------------------
# Validación BAM
# --------------------------------------------------------------
samtools flagstat "${sorted_bam}" > "${output_dir}/${sample_name}_sorted_flagstat.log"

if grep -q "in total" "${output_dir}/${sample_name}_sorted_flagstat.log"; then
  echo "Archivo BAM ordenado válido: ${sorted_bam}"
else
  echo "ADVERTENCIA: BAM posiblemente vacío o dañado. Revisa: ${output_dir}/${sample_name}_sorted_flagstat.log"
  exit 5
fi

echo "Proceso finalizado exitosamente para la muestra ${sample_name}."
