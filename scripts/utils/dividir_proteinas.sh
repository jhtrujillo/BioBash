#!/bin/bash

###############################################################################
# Script: dividir_proteinas.sh
# Descripción: Divide un archivo FASTA de proteínas en varios archivos,
#              asegurando que cada subarchivo tenga no más del número
#              especificado de proteínas.
#
# Uso:
#   ./dividir_proteinas.sh -p <input_fasta> -o <output_prefix> -n <max_proteinas>
#
# Ejemplo:
#   ./dividir_proteinas.sh -p proteinas.fasta -o lote -n 1500
#
# Autor: Inteligencia Artificial (Cenicaña)
# Fecha: 14 de mayo de 2025
###############################################################################

# Mostrar ayuda
mostrar_ayuda() {
  echo "Uso: $0 -p <input_fasta> -o <output_prefix> -n <max_proteinas>"
  echo "  -p <input_fasta>: Archivo FASTA de entrada."
  echo "  -o <output_prefix>: Prefijo para los archivos de salida."
  echo "  -n <max_proteinas>: Número máximo de proteínas por archivo."
  exit 1
}

# Valor por defecto
max_proteinas=1200

# Leer argumentos
while getopts ":p:o:n:" opt; do
  case ${opt} in
    p) proteinas=$OPTARG ;;
    o) salida_prefix=$OPTARG ;;
    n) max_proteinas=$OPTARG ;;
    *) mostrar_ayuda ;;
  esac
done

# Validar argumentos
if [ -z "$proteinas" ] || [ -z "$salida_prefix" ] || [ -z "$max_proteinas" ]; then
  mostrar_ayuda
fi

if [[ ! "$max_proteinas" =~ ^[0-9]+$ ]] || (( max_proteinas < 1 )); then
  echo "Error: El número máximo de proteínas debe ser un entero positivo."
  mostrar_ayuda
fi

if [ ! -f "$proteinas" ]; then
  echo "Error: El archivo '$proteinas' no existe."
  exit 1
fi

# Inicialización
contador=1
contador_proteinas=0
archivo_salida="${salida_prefix}_${contador}.fasta"
> "$archivo_salida"
declare -A conteo_por_archivo

# Leer línea por línea
while IFS= read -r linea; do
  if [[ "$linea" == ">"* ]]; then
    if (( contador_proteinas == max_proteinas )); then
      conteo_por_archivo["$archivo_salida"]=$contador_proteinas
      contador=$((contador + 1))
      archivo_salida="${salida_prefix}_${contador}.fasta"
      > "$archivo_salida"
      contador_proteinas=0
    fi
    contador_proteinas=$((contador_proteinas + 1))
  fi
  echo "$linea" >> "$archivo_salida"
done < "$proteinas"

# Guardar el último conteo
conteo_por_archivo["$archivo_salida"]=$contador_proteinas

# Reporte
echo "División completada. Detalle de proteínas por archivo (máximo $max_proteinas):"
for archivo in "${!conteo_por_archivo[@]}"; do
  echo "$archivo: ${conteo_por_archivo[$archivo]} proteínas"
done
