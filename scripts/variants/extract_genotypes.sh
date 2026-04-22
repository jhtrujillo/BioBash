#!/bin/bash

# Uso: ./extract_genotypes.sh archivo.csv lista_snps.txt [lista_individuos.txt]

ARCHIVO_CSV=$1
LISTA_SNPS=$2
LISTA_INDIVIDUOS=$3

if [[ ! -f "$ARCHIVO_CSV" || ! -f "$LISTA_SNPS" ]]; then
    echo "Uso: $0 archivo.csv lista_snps.txt [lista_individuos.txt]"
    exit 1
fi

# 1. Definir los índices de las columnas
if [[ -f "$LISTA_INDIVIDUOS" ]]; then
    # Obtener índices de los individuos solicitados (manteniendo columna 1)
    IND_PATT=$(tr -d '\r' < "$LISTA_INDIVIDUOS" | paste -sd '|' -)
    IDXS=$(head -n 1 "$ARCHIVO_CSV" | tr ',' '\n' | tr -d '\r' | nl -v 1 | \
          grep -E "^[[:space:]]+[0-9]+[[:space:]]+(Marker|($IND_PATT))$" | \
          awk '{print $1}' | tr '\n' ',')
else
    # Si no hay lista, usar columna 1 (Marker) y de la 6 en adelante (Individuos)
    # Primero obtenemos el número total de columnas
    TOTAL_COLS=$(head -n 1 "$ARCHIVO_CSV" | tr ',' '\n' | wc -l)
    IDXS="1,"$(seq -s, 6 $TOTAL_COLS)
fi

# Limpiar coma final si existe
IDXS=$(echo $IDXS | sed 's/,$//')

# 2. Procesar con AWK
awk -F',' -v snps_file="$LISTA_SNPS" -v idxs_str="$IDXS" '
    BEGIN {
        # Cargar lista de SNPs buscados
        while ((getline < snps_file) > 0) {
            gsub(/\r/, "", $0);
            if ($0 != "") snp_list[$0] = 1
        }
        # Convertir cadena de índices en un arreglo
        n_idx = split(idxs_str, target_cols, ",")
    }
    
    {
        # Obtener el prefijo del marcador (ej: de 1_10058043_T_C extrae 1_10058043)
        # En la primera línea (NR==1), "prefix" será "Marker"
        match($1, /^[0-9]+_[0-9]+/)
        prefix = (NR == 1) ? "Marker" : substr($1, RSTART, RLENGTH)

        # Si es la cabecera O el prefijo está en nuestra lista de SNPs
        if (NR == 1 || prefix in snp_list) {
            for (i = 1; i <= n_idx; i++) {
                printf "%s%s", $target_cols[i], (i == n_idx ? "" : ",")
            }
            print ""
        }
    }
' "$ARCHIVO_CSV"
