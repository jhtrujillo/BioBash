#!/bin/bash

# Función de ayuda
usage() {
  echo "Uso:"
  echo "  $0 --ref <reference.fasta> --ploidy <int> --threads <int> --bam-dir <ruta_bams> --output-vcf <salida.vcf.gz>"
  echo ""
  echo "Ejemplo:"
  echo "  $0 --ref genoma.fasta --ploidy 10 --threads 8 --bam-dir ./bams --output-vcf variantes.vcf.gz"
  exit 1
}

# Leer argumentos nombrados
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --ref) REF="$2"; shift ;;
    --ploidy) PLOIDY="$2"; shift ;;
    --threads) THREADS="$2"; shift ;;
    --bam-dir) BAM_DIR="$2"; shift ;;
    --output-vcf) OUTPUT_VCF="$2"; shift ;;
    -h|--help) usage ;;
    *) echo "Parámetro desconocido: $1"; usage ;;
  esac
  shift
done

# Validación de parámetros obligatorios
if [ -z "$REF" ] || [ -z "$PLOIDY" ] || [ -z "$THREADS" ] || [ -z "$BAM_DIR" ] || [ -z "$OUTPUT_VCF" ]; then
  echo "Faltan parámetros obligatorios."
  usage
fi

# Verificar existencia de archivo de referencia
if [ ! -f "$REF" ]; then
  echo "El archivo de referencia no existe: $REF"
  exit 1
fi

# Verificar y generar .dict si no existe
DICT="${REF%.fasta}.dict"
if [ ! -f "$DICT" ]; then
  echo "No se encontró el archivo .dict. Generándolo..."
  gatk CreateSequenceDictionary -R "$REF"
fi

# Verificar y generar .fai si no existe
if [ ! -f "$REF.fai" ]; then
  echo "No se encontró el índice .fai. Generándolo..."
  samtools faidx "$REF"
fi

# Verificar directorio de BAMs
if [ ! -d "$BAM_DIR" ]; then
  echo "El directorio de BAMs no existe: $BAM_DIR"
  exit 1
fi

# Ejecutar HaplotypeCaller en paralelo por cada BAM
echo "Ejecutando HaplotypeCaller en paralelo..."
find "$BAM_DIR" -name "*.bam" | parallel -j "$THREADS" --joblog parallel_hc.log --verbose '
  BAM={}
  SAMPLE=$(basename {} _all_sorted.bam)
  echo "Procesando $SAMPLE"
  gatk HaplotypeCaller \
    -R '"$REF"' \
    -I "$BAM" \
    -O ${SAMPLE}.g.vcf.gz \
    --emit-ref-confidence GVCF \
    --sample-ploidy '"$PLOIDY"' \
    --minimum-mapping-quality 30 \
    --min-base-quality-score 30 \
    || echo "ERROR: Falló HaplotypeCaller para $SAMPLE" >&2
'

# Validar generación de archivos g.vcf.gz
if ! ls *.g.vcf.gz 1>/dev/null 2>&1; then
  echo "No se generaron archivos .g.vcf.gz. Verifica errores en parallel_hc.log."
  exit 1
fi

# Crear lista de GVCFs
ls *.g.vcf.gz | awk '{print "--variant " $1}' > gvcf_list.txt

# Combinar GVCFs
echo "Combinando GVCFs..."
gatk CombineGVCFs \
  -R "$REF" \
  $(cat gvcf_list.txt) \
  -O combined_tmp.g.vcf.gz

# Genotipado conjunto
echo "Ejecutando GenotypeGVCFs..."
gatk GenotypeGVCFs \
  -R "$REF" \
  -V combined_tmp.g.vcf.gz \
  -O "$OUTPUT_VCF"

echo "Proceso completado. Archivo final: $OUTPUT_VCF"
