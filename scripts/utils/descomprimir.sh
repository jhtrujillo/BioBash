#!/bin/bash

# --------------------------------------------------------------
# Script para descomprimir un archivo .bz2 y moverlo a la carpeta
# especificada, verificando si ya está descomprimido antes de hacerlo.
#
# Uso:
#   ./descomprimir_bz2.sh -f <archivo_comprimido.bz2> -d <directorio_destino> -p <procesadores>
#
# Requisitos:
#   - pbzip2 (debe estar instalado)
# --------------------------------------------------------------

# Mostrar uso del script
show_help() {
    echo "Uso: $0 -f <archivo_comprimido.bz2> -d <directorio_destino> -p <procesadores>"
    echo ""
    echo "  -f    Archivo .bz2 a descomprimir"
    echo "  -d    Directorio de destino donde se guardará el archivo descomprimido"
    echo "  -p    Número de procesadores a usar con pbzip2"
    exit 1
}

# Inicializar variables
FILE=""
DEST_DIR=""
PROCESSORS=4  # Valor predeterminado de procesadores (puedes ajustar)

# Analizar argumentos
while getopts ":f:d:p:h" opt; do
    case $opt in
        f) FILE="$OPTARG" ;;
        d) DEST_DIR="$OPTARG" ;;
        p) PROCESSORS="$OPTARG" ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# Validar parámetros
if [[ -z "$FILE" || -z "$DEST_DIR" ]]; then
    echo "Error: Los parámetros -f (archivo) y -d (directorio) son obligatorios."
    show_help
fi

# Verificar si el archivo existe
if [[ ! -f "$FILE" ]]; then
    echo "Error: El archivo no existe: $FILE"
    exit 1
fi

# Extraer el nombre del archivo descomprimido sin la extensión .bz2
output_file="$DEST_DIR/$(basename "$FILE" .bz2)"

# Verificar si el archivo descomprimido ya existe
if [[ -f "$output_file" ]]; then
    echo "El archivo descomprimido ya existe: $output_file"
    echo "Se omite la descompresión del archivo."
    exit 0
fi

# Verificar si el directorio de destino existe, si no, crear
if [[ ! -d "$DEST_DIR" ]]; then
    echo "El directorio de destino no existe. Creando: $DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

# Mostrar las rutas que se utilizarán para la descompresión
echo "Descomprimiendo $FILE en $DEST_DIR usando $PROCESSORS procesadores..."

# Descomprimir el archivo usando pbzip2 con el número de procesadores especificado
pbzip2 -d -p"$PROCESSORS" -c "$FILE" > "$output_file"

# Verificar si la descompresión fue exitosa
if [[ $? -eq 0 ]]; then
    echo "Descompresión completada con éxito. El archivo descomprimido está en: $output_file"
else
    echo "Error: Hubo un problema durante la descompresión."
    exit 2
fi
