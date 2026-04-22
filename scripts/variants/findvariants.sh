#!/bin/bash

################################################################################
# Script: findVariants
# Descripción:
#   Este script ejecuta NGSEP para detectar variantes en una muestra individual
#   usando un archivo BAM de entrada. Puede incluir un archivo VCF con variantes
#   conocidas si se especifica.
#
# Uso:
#   ./findVariants -b <ruta_al_bam> -o <vcf_de_salida> [-k <vcf_conocido>]
#
# Ejemplo:
#   ./findVariants -b sample01_aln_sorted.bam \
#                  -o /ruta/salida/sample01_variant.vcf \
#                  -k /ruta/AllSamples_variants.vcf
################################################################################

# ----------------------------------------------------------------------------
# Parseo de argumentos
# ----------------------------------------------------------------------------
while getopts "b:o:k:" opt; do
    case "$opt" in
        b) path="$OPTARG" ;;
        o) variant_file="$OPTARG" ;;
        k) known_variants="$OPTARG" ;;
        *)
            echo "Uso: $0 -b <ruta_al_bam> -o <vcf_de_salida> [-k <vcf_conocido>]"
            exit 1
            ;;
    esac
done

# Verificar que se proporcionaron los parámetros obligatorios
if [[ -z "$path" || -z "$variant_file" ]]; then
    echo "Error: Debes proporcionar la ruta al archivo BAM con -b y el archivo VCF de salida con -o."
    echo "Uso: $0 -b <ruta_al_bam> -o <vcf_de_salida> [-k <vcf_conocido>]"
    exit 1
fi

# ----------------------------------------------------------------------------
# Extraer el nombre del archivo y el directorio
# ----------------------------------------------------------------------------
filename=$(basename "$path")
dirpath=$(dirname "$path")
ind=$(echo "$filename" | cut -d'_' -f1)

# (Opcional) Mostrar información del archivo procesado
printf "Nombre del archivo: %s\n" "$filename"
printf "Directorio: %s\n" "$dirpath"

# ----------------------------------------------------------------------------
# Configuración de variables
# ----------------------------------------------------------------------------
sample_id="$ind"
#reference="/biodata7/proyectos/ensamblajeCC01-1940/v2/genoma_enmascarado/cc-01-1940_flye_polishing_allhic_ngsepBuilder_enmascarado.fasta"

#reference="/biodata7/proyectos/references_bank/R570/Saccharum_hybrid_cultivar_R570.assembly.fna"

reference="/biodata5/proyectos/llamado_variantes_olivier/referencia_r570/SofficinarumxspontaneumR570_771_v2.0_monoploid.hardmasked.fasta"

# Obtener ruta base del archivo de salida (sin .vcf)
variant_base="${variant_file%.vcf}"
log_file="${variant_base}_bowtie2_NGSEP_gt.log"

# ----------------------------------------------------------------------------
# Ejecución de NGSEP si el archivo aún no ha sido generado
# ----------------------------------------------------------------------------
if [ ! -f "$variant_file" ]; then
    echo "Ejecutando NGSEP para la muestra: $sample_id"

    cmd=(
        java -XX:MaxHeapSize=30g -jar /biodata1/biotools/ngsep/NGSEPcore/NGSEPcore_5.0.0.jar SingleSampleVariantsDetector
    )

    # Agregar -knownVariants si se especificó
    if [ -n "$known_variants" ]; then
        cmd+=( -knownVariants "$known_variants" )
    fi

    # Parámetros comunes
    cmd+=(
        -ignore5 0
        -ignore3 0
        -sampleId "$sample_id"
        -ploidy 10 \
        -minMQ 30 \
        -maxBaseQS 30 \
        -ignore5 5 \
        -ignore3 5  \
        -maxAlnsPerStartPos 100 \
        -r "$reference"
        -o "$variant_base"
        -i "$path"
    )

    # Ejecutar comando completo y redirigir salida al log
    "${cmd[@]}" >& "$log_file"
else
    printf "El archivo de variantes ya existe: %s\n" "$variant_file"
fi
