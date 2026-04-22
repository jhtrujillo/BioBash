#!/bin/bash

# --------------------------------------------------------------
# Script para extraer el nombre del archivo y el ID de la muestra
# desde un archivo BAM o CRAM comprimido (CRAM con extensión .bz2)
# y mostrar la salida en formato: <nombre_archivo> <ID_muestra>
#
# Uso:
#   ./get_bam_cram_id.sh <archivo.bam/cram/bz2>
#
# --------------------------------------------------------------

# Función para mostrar el uso del script
show_help() {
    echo "Uso: $0 <archivo.bam/cram/bz2>"
    exit 1
}

# Verificar si se proporcionó un archivo
if [ $# -ne 1 ]; then
    echo "Error: Se debe proporcionar un archivo BAM o CRAM."
    show_help
fi

# Obtener el archivo de entrada
file=$1

# Verificar si el archivo existe
if [ ! -f "$file" ]; then
    echo "Error: El archivo no existe: $file"
    exit 2
fi

# Extraer el nombre del archivo
filename=$(basename "$file")

# Si el archivo es .bz2 (CRAM comprimido), usamos bzcat para descomprimir sobre la marcha
if [[ "$filename" == *.bz2 ]]; then
    # Usamos bzcat para descomprimir el archivo CRAM sobre la marcha
    sample_id=$(bzcat "$file" | samtools view -H - | grep "@RG" | awk '{for(i=1;i<=NF;i++) if($i ~ /^ID:/) print $i}' | cut -d':' -f2)
else
    # Si no es un archivo comprimido, procesamos el archivo directamente
    sample_id=$(samtools view -H "$file" | grep "@RG" | awk '{for(i=1;i<=NF;i++) if($i ~ /^ID:/) print $i}' | cut -d':' -f2)
fi

# Verificar si se encontró el ID de la muestra
if [ -z "$sample_id" ]; then
    echo "Error: No se pudo encontrar el ID de la muestra en la cabecera del archivo."
    exit 3
fi

# Mostrar los resultados en el formato solicitado
echo "$filename  $sample_id"

