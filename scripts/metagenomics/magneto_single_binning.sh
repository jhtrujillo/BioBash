#!/bin/bash

# Este script automatiza el flujo de trabajo de indexación con BWA,
# cálculo de profundidad de contigs con jgi_summarize_bam_contig_depths,
# y binning de genomas con MetaBAT2.

# --- Bloque de Comentarios: Cómo ejecutar el script ---
#
# Para ejecutar este script, utiliza la siguiente sintaxis en tu terminal:
#
# bash nombre_del_script.sh -g <ruta_a_genome.fasta> -b <ruta_a_bam_alineado.bam> -o <ruta_directorio_de_resultados>
#
# Ejemplos de uso:
#
# 1. Ejecución básica:
#    bash run_metagenomics_workflow.sh -g D9.contigs.fa -b J11.sorted.bam -o bins/MiProyecto_Bins
#    Esto creará el directorio 'bins/MiProyecto_Bins/'
#    Archivo de profundidad: 'bins/MiProyecto_Bins/depth_D9.contigs_J11.sorted.bam.txt'
#    Bins: 'bins/MiProyecto_Bins/MiProyecto_Bins.1.fa', 'bins/MiProyecto_Bins/MiProyecto_Bins.2.fa', etc.
#
# 2. Tu caso específico:
#    bash run_metagenomics_workflow.sh -g contigs/D9.contigs.fa -b mapeo_reads/D9/J11.sorted.bam -o binns/bin_D9
#    Esto creará el directorio 'binns/bin_D9/'
#    Archivo de profundidad: 'binns/bin_D9/depth_D9.contigs_J11.sorted.bam.txt'
#    Bins: 'binns/bin_D9/bin_D9.1.fa', 'binns/bin_D9/bin_D9.2.fa', etc.
#
# Parámetros requeridos:
#    -g    Ruta al archivo FASTA del genoma (ej. D9.contigs.fa)
#    -b    Ruta al archivo BAM alineado (ej. J11.sorted.bam)
#    -o    Ruta del directorio donde se guardarán TODOS los resultados (bins y archivo de profundidad).
#          El nombre de este directorio también se usará como prefijo para los archivos de bins.
#    -h    Muestra este mensaje de ayuda
#
# --------------------------------------------------------

# Variables para almacenar los parámetros
GENOME_FASTA=""
ALIGNED_BAM=""
# NEW: RESULTS_OUTPUT_DIR will be the single variable for the output directory
RESULTS_OUTPUT_DIR=""

# Function to display the help message
usage() {
    echo "Uso: $0 -g <ruta_a_genome.fasta> -b <ruta_a_bam_alineado.bam> -o <ruta_directorio_de_resultados>"
    echo " "
    echo "Opciones:"
    echo "  -g    Ruta al archivo FASTA del genoma (ej. D9.contigs.fa)"
    echo "  -b    Ruta al archivo BAM alineado (ej. J11.sorted.bam)"
    echo "  -o    Ruta del directorio donde se guardarán TODOS los resultados (bins y archivo de profundidad)."
    echo "        El nombre de este directorio se usará como prefijo para los bins."
    echo "        Ej: -o 'mis_resultados/proyecto_X' creará 'mis_resultados/proyecto_X/proyecto_X.1.fa'"
    echo "  -h    Muestra este mensaje de ayuda"
    exit 1
}

# Parse input parameters
while getopts "g:b:o:h" opt; do
    case ${opt} in
        g )
            GENOME_FASTA=$OPTARG
            ;;
        b )
            ALIGNED_BAM=$OPTARG
            ;;
        o )
            RESULTS_OUTPUT_DIR=$OPTARG # Store the full path for the output directory
            ;;
        h )
            usage
            ;;
        \? )
            echo "Opción inválida: -$OPTARG" >&2
            echo ""
            usage
            ;;
        : )
            echo "La opción -$OPTARG requiere un argumento." >&2
            echo ""
            usage
            ;;
    esac
done
shift $((OPTIND -1))

# Verify that all required parameters have been provided
if [ -z "$GENOME_FASTA" ] || [ -z "$ALIGNED_BAM" ] || [ -z "$RESULTS_OUTPUT_DIR" ]; then
    echo "Error: Faltan parámetros requeridos."
    usage
fi

# Ensure RESULTS_OUTPUT_DIR does not end with a slash for consistent basename behavior
RESULTS_OUTPUT_DIR=$(echo "$RESULTS_OUTPUT_DIR" | sed 's/\/$//')

# Determine the prefix for bin files based on the last part of RESULTS_OUTPUT_DIR
BIN_FILENAME_PREFIX=$(basename "$RESULTS_OUTPUT_DIR")

# Handle cases where RESULTS_OUTPUT_DIR might be empty or just a slash, although 'getopts' should prevent empty.
if [ -z "$BIN_FILENAME_PREFIX" ]; then
    echo "Error: El directorio de salida proporcionado es inválido o no tiene nombre. No se puede determinar el prefijo para los bins." >&2
    usage
fi

# Full path to the MetaBAT2 output prefix (directory + filename prefix)
METABAT_OUTPUT_PREFIX="${RESULTS_OUTPUT_DIR}/${BIN_FILENAME_PREFIX}"


echo "--- Iniciando el flujo de trabajo ---"
echo "Genoma FASTA: $GENOME_FASTA"
echo "BAM Alineado: $ALIGNED_BAM"
echo "Directorio de salida para TODOS los resultados: $RESULTS_OUTPUT_DIR"
echo "Prefijo de nombre para los archivos de bins: $BIN_FILENAME_PREFIX"
echo "Prefijo COMPLETO que se pasará a MetaBAT2: $METABAT_OUTPUT_PREFIX"

#---
## Configuración del Ambiente
#---

echo "Activando ambiente Conda: bowtie_env_py310"
eval "$(conda shell.bash hook)"
conda activate /biodata4/ambientes_conda/miniforge3/envs/bowtie_env_py310/

if [ $? -ne 0 ]; then
    echo "Error: No se pudo activar el ambiente Conda 'bowtie_env_py310'. Asegúrate de que existe y conda está configurado correctamente."
    exit 1
fi
echo "Ambiente Conda activado."

#---
## Verificación de Índices BWA
#---

# Verificar si los archivos de índice ya existen
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
        break
    fi
done

if $INDEX_EXISTS; then
    echo "Los índices de BWA para $GENOME_FASTA ya existen. Procediendo con el flujo de trabajo."
else
    echo "Error: Los índices de BWA para $GENOME_FASTA no existen. Por favor, indexe el genoma con 'bwa index $GENOME_FASTA' antes de ejecutar este script."
    exit 1
fi

---
## Preparación del Directorio de Salida
---

# Crear el directorio FINAL donde se guardarán los bins y el archivo de profundidad
if [ ! -d "$RESULTS_OUTPUT_DIR" ]; then
    echo "Creando el directorio de resultados: $RESULTS_OUTPUT_DIR"
    mkdir -p "$RESULTS_OUTPUT_DIR"
fi


#---
## Cálculo de Profundidad de Cobertura
#---

BAM_BASENAME=$(basename "$ALIGNED_BAM")
GENOME_BASENAME=$(basename "$GENOME_FASTA")
GENOME_BASENAME="${GENOME_BASENAME%.*}" # Remove FASTA file extension

# The depth file will now be saved in RESULTS_OUTPUT_DIR
DEPTH_FILE="${RESULTS_OUTPUT_DIR}/depth_${GENOME_BASENAME}_${BAM_BASENAME}.txt"
echo "El archivo de profundidad se guardará como: $DEPTH_FILE"

echo "Calculando profundidad de cobertura por contig desde $ALIGNED_BAM..."
jgi_summarize_bam_contig_depths --outputDepth "$DEPTH_FILE" "$ALIGNED_BAM"

if [ $? -ne 0 ]; then
    echo "Error: Falló el cálculo de profundidad con jgi_summarize_bam_contig_depths."
    exit 1
fi
echo "Cálculo de profundidad completado. Salida: $DEPTH_FILE"

#---
## Ejecución de MetaBAT2 para el Binning
#---

echo "--- DEPURACIÓN PRE-METABAT2 ---"
echo "Valor que se pasa a -o de MetaBAT2 (METABAT_OUTPUT_PREFIX): [${METABAT_OUTPUT_PREFIX}]"
echo "Directorio donde se espera que queden los archivos (RESULTS_OUTPUT_DIR): [${RESULTS_OUTPUT_DIR}]"
echo "Prefijo de nombre de archivo esperado (BIN_FILENAME_PREFIX): [${BIN_FILENAME_PREFIX}]"
echo "Comando MetaBAT2 a ejecutar: metabat2 -i \"$GENOME_FASTA\" -a \"$DEPTH_FILE\" -o \"$METABAT_OUTPUT_PREFIX\""
echo "------------------------------"

echo "Ejecutando MetaBAT2 para agrupar contigs en bins..."
metabat2 -i "$GENOME_FASTA" -a "$DEPTH_FILE" -o "$METABAT_OUTPUT_PREFIX"

if [ $? -ne 0 ]; then
    echo "Error: Falló la ejecución de MetaBAT2."
    exit 1
fi
echo "MetaBAT2 completado. Bins generados en $RESULTS_OUTPUT_DIR con prefijo $BIN_FILENAME_PREFIX."

echo "--- Flujo de trabajo completado exitosamente ---"
