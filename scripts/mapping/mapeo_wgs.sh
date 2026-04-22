#!/bin/bash
# --------------------------------------------------------------
# Script para mapear lecturas pareadas (WGS) con Bowtie2 + Samtools
# Robusto para HPC: controla memoria/tmp de samtools sort y evita "Too many open files"
# --------------------------------------------------------------
# Uso: ./mapeo_wgs.sh <individuo> <referencia> <workdir> <procesadores> [I=200] [X=400]
# Ejemplo:
# ./mapeo_wgs.sh IND01 /ruta/referencia.fasta /ruta/resultados 32
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
# Cargar configuración si existe (soporte para ejecución independiente)
# --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_BASE="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ -f "$SUITE_BASE/lib/load_config.sh" ]]; then
    source "$SUITE_BASE/lib/load_config.sh"
fi

# --------------------------------------------------------------
# Entradas y parámetros
# --------------------------------------------------------------
ind="$1"
reference="$2"
workdir="$3"
proc="${4:-$DEFAULT_PROC}"
i="${5:-$DEFAULT_I}"
x="${6:-$DEFAULT_X}"
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
# Usamos BIODATA_WGS y CONSECUTIVOS_FILE definidos en la config
idWGS=$(awk -v individuo="${ind}" '{if ($2==individuo) print $1}' "${CONSECUTIVOS_FILE:-/biodata2/HTS/WGS/consecutivosEI-Cenicana.txt}" || true)
if [ -z "${idWGS}" ]; then
  echo "ERROR: No se encontró el ID para el individuo '${ind}' en ${CONSECUTIVOS_FILE:-/biodata2/HTS/WGS/consecutivosEI-Cenicana.txt}"
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

# --------------------------------------------------------------
# Ajustes robustos para samtools sort (mejor recomendación)
#   - Limita hilos de sort (tope 32) aunque Bowtie2 use más
#   - Asigna memoria por hilo para evitar miles de temporales
#   - Usa TMPDIR local si existe para temporales
#   - Intenta subir ulimit -n si el sistema lo permite
# --------------------------------------------------------------
tmp_root="${TMPDIR:-${output_dir}/tmp}"
tmp_dir="${tmp_root}/${ind}_samtools_tmp"
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

# Memoria por hilo para sort:
# usa ~70% de MemAvailable repartida entre sort_threads, min 1G, max 4G por hilo
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
# Estrategia más estable en HPC: BAM intermedio + sort
#   (reduce presión de temporales y facilita reintentos)
# --------------------------------------------------------------
unsorted_bam="${output_dir}/${ind}.bam"

# 1) Mapeo -> BAM sin ordenar
bowtie2 --rg-id "${ind}" --rg "${s}" --rg PL:ILLUMINA \
  -I "${i}" -X "${x}" -p "${proc}" -k 3 -t \
  -x "${INDEXES}" -1 "${f1}" -2 "${f2}" 2> "${log_bt2}" \
| samtools view -bhS -o "${unsorted_bam}" -

# 2) Ordenar BAM (controlando memoria, tmp y hilos)
samtools sort \
  -@ "${sort_threads}" \
  -m "${sort_mem}" \
  -T "${tmp_dir}/${ind}.tmp" \
  -o "${sorted_bam}" \
  "${unsorted_bam}"

# 3) Limpiar BAM intermedio (opcional, comenta si lo quieres conservar)
rm -f "${unsorted_bam}"

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