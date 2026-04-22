#!/bin/bash

# --------------------------------------------------------------
# Script: multisamplevariantsdetectorbyChr.sh
# Autor: Jhon Henry Trujillo Montenegro
# Fecha: 22 de abril de 2025
# Descripción:
#    Este script extrae eficientemente lecturas para un cromosoma específico
#    desde múltiples archivos BAM o CRAM ubicados en un directorio de entrada
#    definido por el usuario. Utiliza el comando 'find' para localizar estos
#    archivos y un bucle para procesarlos secuencialmente. Llama a un script
#    externo ('/biodata4/proyectos/scripts/extraer_cromosoma_desde_bam.sh')
#    para realizar la extracción del cromosoma en cada archivo de entrada.
#    Los archivos resultantes específicos del cromosoma se guardan en una
#    subcarpeta temporal dentro del directorio de entrada, con el nombre del
#    cromosoma. Opcionalmente, puede ejecutar un script de llamado de variantes
#    y luego limpiar los archivos temporales extraídos.
#
#    Este código fue desarrollado con el apoyo de ChatGPT y Gemini.
#
# Uso:
#    ./multisamplevariantsdetectorbyChr.sh -d <directorio_entrada> -c <cromosoma> [-p <procesadores>] [-r <referencia_fasta>] [-o <ruta_archivo_vcf>]
#
# Ejemplo:
#    ./multisamplevariantsdetectorbyChr.sh -d todos_bams -c chr2 -p 16 -r /ruta/a/referencia.fasta -o variantes/salida_chr2.vcf
# --------------------------------------------------------------

# --------------------------------------------------------------
# Definir las opciones aceptadas por el script
# --------------------------------------------------------------
OPTS="d:c:p:"

# --------------------------------------------------------------
# Utilizar getopt para analizar las opciones y sus argumentos
# --------------------------------------------------------------
while getopts "$OPTS" opt; do
  case "$opt" in
    d) directorio_entrada="$OPTARG" ;;
    c) cromosoma="$OPTARG" ;;
    p) procesadores="$OPTARG" ;;
    \?) echo "Uso: $0 -d <directorio_entrada> -c <cromosoma> [-p <procesadores>]" >&2; exit 1 ;;
  esac
done

# --------------------------------------------------------------
# Eliminar las opciones ya procesadas de la lista de argumentos
# --------------------------------------------------------------
shift $((OPTIND - 1))

# --------------------------------------------------------------
# Verificar que se hayan proporcionado los argumentos obligatorios
# --------------------------------------------------------------
if [ -z "$directorio_entrada" ] || [ -z "$cromosoma" ]; then
  echo "Error: Los argumentos -d (directorio de entrada) y -c (cromosoma) son obligatorios." >&2
  echo "Uso: $0 -d <directorio_entrada> -c <cromosoma> [-p <procesadores>]" >&2
  exit 1
fi

# --------------------------------------------------------------
# Establecer valor por defecto para el número de procesadores
# --------------------------------------------------------------
if [ -z "$procesadores" ]; then
  procesadores=20
fi

# --------------------------------------------------------------
# Definir el directorio temporal para los archivos extraídos
# --------------------------------------------------------------
directorio_temporal="$directorio_entrada/$cromosoma"_temp

# --------------------------------------------------------------
# Crear el directorio temporal si no existe
# --------------------------------------------------------------
mkdir -p "$directorio_temporal"

# --------------------------------------------------------------
# Buscar archivos BAM/CRAM y extraer el cromosoma usando un bucle for (secuencial)
# --------------------------------------------------------------
for archivo_bam in $(find "$directorio_entrada" -maxdepth 1 -type f \( -name "*.bam" -o -name "*.cram" \)); do
  # Ejecutar el script de extracción para cada archivo, uno por uno
  echo "Extrayendo cromosoma $cromosoma del archivo: $archivo_bam usando $procesadores procesadores."
  /biodata4/proyectos/scripts/extraer_cromosoma_desde_bam.sh -b "$archivo_bam" -c "$cromosoma" -o "$directorio_temporal" -p "$procesadores"
done


# --------------------------------------------------------------
# Salir del script
# --------------------------------------------------------------
exit 0
