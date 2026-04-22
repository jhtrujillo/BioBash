#!/bin/bash
# --------------------------------------------------------------
# Mapeo de lecturas pareadas contra hospedero
# Salidas:
#   1) BAM total ordenado
#   2) BAM de alineamientos primarios perfectos al hospedero
#      - 100% identidad: NM:i:0
#      - 100% cobertura del read: CIGAR = longitud_del_read + "M"
#   3) FASTQ de lecturas que NO cumplen ese criterio
# --------------------------------------------------------------
# Uso:
# ./mapeo_pareado_perfecto_y_nohost.sh <R1.fastq.gz> <R2.fastq.gz> <referencia> <workdir> <procesadores> [I=200] [X=400] [sample_name]
# --------------------------------------------------------------

set -euo pipefail

if [ $# -lt 5 ]; then
  echo "USO: $0 <R1.fastq.gz> <R2.fastq.gz> <referencia> <workdir> <procesadores> [I=200] [X=400] [sample_name]"
  exit 1
fi

f1="$1"
f2="$2"
reference="$3"
workdir="$4"
proc="$5"
i="${6:-200}"
x="${7:-400}"
sample_name="${8:-}"

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

directorio="$(dirname "$reference")"
base="$(basename "$reference")"
base="${base%.gz}"
base="${base%.fasta}"
base="${base%.fa}"
base="${base%.fna}"
INDEXES="${directorio}/${base}"

output_dir="${workdir}/${sample_name}_${base}"
mkdir -p "$output_dir"

sorted_bam="${output_dir}/${sample_name}_sorted.bam"
perfect_bam="${output_dir}/${sample_name}_perfect_primary.bam"
nonperfect_names="${output_dir}/${sample_name}_nonperfect_readnames.txt"
nonperfect_r1="${output_dir}/${sample_name}_nonperfect_R1.fastq.gz"
nonperfect_r2="${output_dir}/${sample_name}_nonperfect_R2.fastq.gz"
log_bt2="${output_dir}/${sample_name}_bowtie2.log"

if [ ! -f "${INDEXES}.1.bt2" ] && [ ! -f "${INDEXES}.1.bt2l" ]; then
  echo "ERROR: No se encontró el índice Bowtie2 con prefijo:"
  echo "  ${INDEXES}"
  echo "Genera el índice con:"
  echo "  bowtie2-build ${reference} ${INDEXES}"
  exit 3
fi

echo "Directorio de trabajo: $output_dir"
echo "Muestra: $sample_name"
echo "Índice Bowtie2 (prefijo): $INDEXES"
echo "Lecturas:"
echo "  R1: $f1"
echo "  R2: $f2"

tmp_root="${TMPDIR:-${output_dir}/tmp}"
tmp_dir="${tmp_root}/${sample_name}_samtools_tmp"
mkdir -p "$tmp_dir"

ulimit -n 65535 2>/dev/null || true

mem_avail_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo "")
if [[ -n "$mem_avail_kb" ]]; then
  mem_avail_gb=$(( mem_avail_kb / 1024 / 1024 ))
else
  mem_avail_gb=$(free -g 2>/dev/null | awk '/^Mem:/ {print $7}' || echo 0)
fi

sort_threads="$proc"
if (( sort_threads > 32 )); then sort_threads=32; fi
if (( sort_threads < 4 )); then sort_threads=4; fi

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

unsorted_bam="${output_dir}/${sample_name}.bam"

# --------------------------------------------------------------
# 1) Mapeo estricto, sin secundarios artificiales por -k
# --------------------------------------------------------------
bowtie2 \
  --rg-id "${sample_name}" \
  --rg "${s}" \
  --rg PL:ILLUMINA \
  --end-to-end \
  --very-sensitive \
  -I "${i}" \
  -X "${x}" \
  -p "${proc}" \
  -t \
  -x "${INDEXES}" \
  -1 "${f1}" \
  -2 "${f2}" \
  2> "${log_bt2}" \
| samtools view -bhS -o "${unsorted_bam}" -

samtools sort \
  -@ "${sort_threads}" \
  -m "${sort_mem}" \
  -T "${tmp_dir}/${sample_name}.tmp" \
  -o "${sorted_bam}" \
  "${unsorted_bam}"

rm -f "${unsorted_bam}"

samtools index -@ "${sort_threads}" "${sorted_bam}"

# --------------------------------------------------------------
# 2) BAM de alineamientos primarios perfectos al hospedero
#    -F 2304 excluye secondary (256) y supplementary (2048)
# --------------------------------------------------------------
samtools view -h -F 2304 "${sorted_bam}" | \
awk 'BEGIN{OFS="\t"}
/^@/ {print; next}
{
  seq_len=length($10)
  if ($6 == seq_len "M" && $0 ~ /NM:i:0(\t|$)/) print
}' | \
samtools view -b -o "${perfect_bam}" -

samtools index -@ "${sort_threads}" "${perfect_bam}"

# --------------------------------------------------------------
# 3) Obtener nombres de lecturas perfectas
# --------------------------------------------------------------
samtools view "${perfect_bam}" | cut -f1 | sort -u > "${output_dir}/${sample_name}_perfect_readnames.txt"

# --------------------------------------------------------------
# 4) Obtener nombres de TODAS las lecturas del FASTQ original
#    y quedarnos con las que NO son perfectas al hospedero
# --------------------------------------------------------------
zcat "$f1" | sed -n '1~4s/^@//p' | sed 's/[[:space:]].*$//' | sort -u > "${output_dir}/${sample_name}_all_readnames.txt"

comm -23 \
  "${output_dir}/${sample_name}_all_readnames.txt" \
  "${output_dir}/${sample_name}_perfect_readnames.txt" \
> "${nonperfect_names}"

# --------------------------------------------------------------
# 5) Extraer FASTQ no perfectas usando seqtk
#    Requiere seqtk instalado
# --------------------------------------------------------------
if ! command -v seqtk >/dev/null 2>&1; then
  echo "ERROR: seqtk no está instalado o no está en PATH."
  echo "Instálalo y vuelve a correr la extracción de FASTQ."
  exit 4
fi

seqtk subseq "$f1" "${nonperfect_names}" | gzip > "${nonperfect_r1}"
seqtk subseq "$f2" "${nonperfect_names}" | gzip > "${nonperfect_r2}"

# --------------------------------------------------------------
# 6) Reportes
# --------------------------------------------------------------
samtools flagstat "${sorted_bam}" > "${output_dir}/${sample_name}_sorted_flagstat.log"
samtools flagstat "${perfect_bam}" > "${output_dir}/${sample_name}_perfect_primary_flagstat.log"

total_primary=$(samtools view -c -F 2304 "${sorted_bam}")
perfect_primary=$(samtools view -c "${perfect_bam}")
nonperfect_count=$(wc -l < "${nonperfect_names}")

{
  echo -e "sample\tprimary_total\tperfect_primary\tpercent_perfect_primary\tnonperfect_reads"
  if [ "${total_primary}" -gt 0 ]; then
    pct=$(awk -v a="${perfect_primary}" -v b="${total_primary}" 'BEGIN{printf "%.4f", (a*100)/b}')
  else
    pct="0.0000"
  fi
  echo -e "${sample_name}\t${total_primary}\t${perfect_primary}\t${pct}\t${nonperfect_count}"
} > "${output_dir}/${sample_name}_perfect_primary_summary.tsv"

echo "Archivo BAM total:                ${sorted_bam}"
echo "Archivo BAM perfect primary:      ${perfect_bam}"
echo "FASTQ no perfectas R1:            ${nonperfect_r1}"
echo "FASTQ no perfectas R2:            ${nonperfect_r2}"
echo "Resumen:                          ${output_dir}/${sample_name}_perfect_primary_summary.tsv"
echo "Proceso finalizado exitosamente para la muestra ${sample_name}."