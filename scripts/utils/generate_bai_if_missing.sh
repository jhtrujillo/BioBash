#!/bin/bash

# ------------------------------------------------------------------------------
# Script: generate_bai_if_missing.sh
# Description:
#   Recibe un archivo .bam con -b y el número de procesadores con -p (opcional).
#   Si el archivo .bai no existe, lo genera en la misma ubicación del BAM.
# ------------------------------------------------------------------------------

# Función de ayuda
function usage {
    echo "Uso: $0 -b <archivo.bam> [-p <procesadores>]"
    echo "Ejemplo: $0 -b /ruta/a/sample.bam -p 8"
    exit 1
}

# Verificar que samtools esté instalado
if ! command -v samtools &>/dev/null; then
    echo "Error: samtools no está instalado o no está en el PATH."
    exit 1
fi

# Valores por defecto
processors=4

# Parsear argumentos
while getopts ":b:p:" opt; do
  case $opt in
    b) bam_file="$OPTARG" ;;
    p) processors="$OPTARG" ;;
    *) usage ;;
  esac
done

# Verificar argumentos obligatorios
if [ -z "${bam_file:-}" ]; then
    usage
fi

# Verificar existencia del archivo BAM
if [ ! -f "$bam_file" ]; then
    echo "Error: el archivo '$bam_file' no existe."
    exit 1
fi

# Obtener ruta absoluta del BAM y su directorio
bam_file_abs="$(readlink -f "$bam_file")"
bam_dir="$(dirname "$bam_file_abs")"
bam_name="$(basename "$bam_file_abs")"

# Ruta del archivo .bai
bai_file="$bam_file_abs.bai"

# Verificar y crear índice si no existe
if [ -f "$bai_file" ]; then
    echo "El archivo índice ya existe: $bai_file"
else
    echo "Generando índice para '$bam_name' con $processors procesador(es)..."
    samtools index -@ "$processors" "$bam_file_abs"
    if [ $? -eq 0 ]; then
        echo "Índice generado exitosamente: $bai_file"
    else
        echo "Error al generar el índice."
        exit 1
    fi
fi
