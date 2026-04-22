#!/bin/bash

# Este script genera los índices para el archivo de contigs usando BWA.
# Si los índices ya existen, el script solo los verificará y no los volverá a generar.

# Variables para el genoma FASTA
GENOME_FASTA=""

# Función para mostrar el mensaje de ayuda
usage() {
    echo "Uso: $0 -g <ruta_a_genome.fasta>"
    echo " "
    echo "Opciones:"
    echo "  -g    Ruta al archivo FASTA del genoma (ej. D9.contigs.fa)"
    echo "  -h    Muestra este mensaje de ayuda"
    exit 1
}

# Parsear los parámetros de entrada
while getopts "g:h" opt; do
    case ${opt} in
        g )
            GENOME_FASTA=$OPTARG
            ;;
        h )
            usage
            ;;
        \? )
            echo "Opción inválida: -$OPTARG" >&2
            usage
            ;;
        : )
            echo "La opción -$OPTARG requiere un argumento." >&2
            usage
            ;;
    esac
done
shift $((OPTIND -1))

# Verificar que el parámetro -g ha sido proporcionado
if [ -z "$GENOME_FASTA" ]; then
    echo "Error: Faltan parámetros requeridos."
    usage
fi

# Verificar si el archivo FASTA de entrada existe
if [ ! -f "$GENOME_FASTA" ]; then
    echo "Error: El archivo FASTA $GENOME_FASTA no existe."
    exit 1
fi

# Verificar si los índices de BWA ya existen
INDEX_FILES=(
    "$GENOME_FASTA.amb"
    "$GENOME_FASTA.ann"
    "$GENOME_FASTA.bwt"
    "$GENOME_FASTA.pac"
    "$GENOME_FASTA.sa"
)

INDEX_EXISTS=true
for file in "${INDEX_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        INDEX_EXISTS=false
        echo "El archivo de índice $file no existe. Generando índices..."
        break
    fi
    # Comprobar que el tamaño del archivo no sea cero, lo que indicaría un archivo vacío
    if [ ! -s "$file" ]; then
        INDEX_EXISTS=false
        echo "El archivo de índice $file está vacío. Generando índices..."
        break
    fi
done

if $INDEX_EXISTS; then
    echo "Los índices de BWA para $GENOME_FASTA ya existen. Saltando la indexación."
else
    echo "Creando índice BWA para $GENOME_FASTA..."
    bwa index "$GENOME_FASTA"

    if [ $? -ne 0 ]; then
        echo "Error: Falló la indexación con BWA."
        exit 1
    fi
    echo "Indexación BWA completada."
fi

echo "--- Script de indexación BWA completado ---"

