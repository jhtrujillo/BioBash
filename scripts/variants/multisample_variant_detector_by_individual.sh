#!/bin/bash

# ------------------------------------------------------------------
# Script: procesar_bam.sh
# Descripción: Este script procesa un archivo BAM y genera un archivo VCF.
# Uso:
#   ./procesar_bam.sh -b <archivo.bam> -o <directorio_salida>
#   -b <archivo.bam>       : Ruta del archivo BAM de entrada.
#   -o <directorio_salida> : Directorio donde se guardará el archivo VCF.
# ------------------------------------------------------------------

# Función para mostrar el uso del script
mostrar_uso() {
  echo "Uso: $0 -b <archivo.bam> -o <directorio_salida>"
  echo "  -b <archivo.bam>      : Archivo BAM de entrada"
  echo "  -o <directorio_salida>: Directorio donde se guardará el archivo VCF"
  exit 1
}

# Parseo de los argumentos
while getopts ":b:o:" opt; do
  case $opt in
    b)
      archivo_bam="$OPTARG"
      ;;
    o)
      directorio_salida="$OPTARG"
      ;;
    *)
      mostrar_uso
      ;;
  esac
done

# Verificar que se hayan proporcionado ambos parámetros
if [ -z "$archivo_bam" ] || [ -z "$directorio_salida" ]; then
  mostrar_uso
fi

# Verificar que el archivo BAM exista
if [ ! -f "$archivo_bam" ]; then
  echo "Error: El archivo '$archivo_bam' no existe."
  exit 1
fi

# Verificar que el directorio de salida exista
if [ ! -d "$directorio_salida" ]; then
  echo "Error: El directorio '$directorio_salida' no existe."
  exit 1
fi

# Obtener el nombre base del archivo BAM sin la extensión
nombre_base=$(basename "$archivo_bam" .bam)

# Ruta del archivo VCF de salida
archivo_vcf="$directorio_salida/$nombre_base.vcf"

# Verificar si el archivo VCF ya existe
if [ -f "$archivo_vcf" ]; then
  echo "El archivo '$archivo_vcf' ya existe. Se omite."
else
  # Ejecutar el comando ngsep para generar el archivo VCF
  echo "Procesando '$archivo_bam'..."
  time JAVA_OPTS="-XX:MaxHeapSize=100g" ngsep MultisampleVariantsDetector \
    -ploidy 10 \
    -r /biodata7/proyectos/ensamblajeCC01-1940/v2/genoma_enmascarado/cc-01-1940_flye_polishing_allhic_ngsepBuilder_enmascarado.fasta \
    -minMQ 5 \
    -maxBaseQS 10 \
    -minQuality 10 \
    -h 0.0000 \
    -psp \
    -o "$archivo_vcf" \
    "$archivo_bam"
fi
