#!/bin/bash

# Este script automatiza la evaluación de la calidad de los bins (MAGs)
# utilizando CheckM en modo 'lineage_wf'.

# --- Bloque de Comentarios: Cómo ejecutar el script ---
#
# Para ejecutar este script, utiliza la siguiente sintaxis en tu terminal:
#
# bash nombre_del_script.sh -f <formato_bin> -i <ruta_entrada_bins> -o <ruta_salida_checkm> -t <num_procesadores> -l <prefijo_log>
#
# Ejemplos de uso:
#
# 1. Ejecución básica:
#    bash run_checkm_workflow.sh -f fa -i bins/ -o checkm_output/ -t 90 -l my_checkm_run
#
# 2. Rutas completas y más procesadores:
#    bash run_checkm_workflow.sh -f fasta -i /data/my_mags/ -o /results/checkm_results/ -t 120 -l project_analysis_logs
#
# Parámetros requeridos:
#   -f  Formato de los archivos de bin (ej. 'fa' o 'fasta').
#   -i  Ruta al directorio de entrada que contiene los archivos de bins.
#   -o  Ruta al directorio de salida donde CheckM guardará sus resultados.
#   -t  Número de procesadores (hilos) a usar por CheckM.
#   -l  Prefijo para el nombre del archivo de log. El log se llamará <prefijo_log>_checkm.txt.
#   -h  Muestra este mensaje de ayuda.
#
# --------------------------------------------------------

# Variables para almacenar los parámetros
BIN_FORMAT=""
INPUT_BIN_DIR=""
OUTPUT_CHECKM_DIR=""
NUM_PROCESSORS=""
LOG_PREFIX=""

# Función para mostrar el mensaje de ayuda
usage() {
    echo "Uso: $0 -f <formato_bin> -i <ruta_entrada_bins> -o <ruta_salida_checkm> -t <num_procesadores> -l <prefijo_log>"
    echo " "
    echo "Opciones:"
    echo "  -f    Formato de los archivos de bin (ej. 'fa' o 'fasta')."
    echo "  -i    Ruta al directorio de entrada que contiene los archivos de bins."
    echo "  -o    Ruta al directorio de salida donde CheckM guardará sus resultados."
    echo "  -t    Número de procesadores (hilos) a usar por CheckM."
    echo "  -l    Prefijo para el nombre del archivo de log. El log se llamará <prefijo_log>_checkm.txt."
    echo "  -h    Muestra este mensaje de ayuda."
    exit 1
}

# Parsear los parámetros de entrada
while getopts "f:i:o:t:l:h" opt; do
    case ${opt} in
        f )
            BIN_FORMAT=$OPTARG
            ;;
        i )
            INPUT_BIN_DIR=$OPTARG
            ;;
        o )
            OUTPUT_CHECKM_DIR=$OPTARG
            ;;
        t )
            NUM_PROCESSORS=$OPTARG
            ;;
        l )
            LOG_PREFIX=$OPTARG
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

# Verificar que todos los parámetros requeridos han sido proporcionados
if [ -z "$BIN_FORMAT" ] || [ -z "$INPUT_BIN_DIR" ] || [ -z "$OUTPUT_CHECKM_DIR" ] || [ -z "$NUM_PROCESSORS" ] || [ -z "$LOG_PREFIX" ]; then
    echo "Error: Faltan parámetros requeridos."
    usage
fi

echo "--- Iniciando la evaluación de bins con CheckM ---"
echo "Formato de Bin: $BIN_FORMAT"
echo "Directorio de entrada de Bins: $INPUT_BIN_DIR"
echo "Directorio de salida de CheckM: $OUTPUT_CHECKM_DIR"
echo "Número de procesadores: $NUM_PROCESSORS"
echo "Prefijo de Log: $LOG_PREFIX"

# --- Activación del ambiente Conda (ajusta el nombre del ambiente si es necesario) ---
echo "Activando ambiente Conda (asumiendo 'checkm_env' o similar)..."
# Asegúrate de que tu shell esté configurado para usar conda (ej. con 'conda init' o 'source /path/to/conda.sh')
eval "$(conda shell.bash hook)"
# Si CheckM está en un ambiente específico, actívalo aquí.
# Por ejemplo, si lo instalaste en un ambiente llamado 'checkm_env':
# conda activate checkm_env
# Si está en tu ambiente base o ya accesible globalmente, puedes comentar la línea de 'conda activate'.
# Por ahora, usaré un nombre genérico, cámbialo si es necesario.
conda activate /biodata4/ambientes_conda/miniforge3/envs/bowtie_env_py310/ # <--- CAMBIA 'checkm_env' por el nombre de tu ambiente CheckM si es diferente

if [ $? -ne 0 ]; then
    echo "Error: No se pudo activar el ambiente Conda. Asegúrate de que el ambiente existe y conda está configurado correctamente."
    exit 1
fi
echo "Ambiente Conda activado."

# --- Crear el directorio de salida de CheckM si no existe ---
if [ ! -d "$OUTPUT_CHECKM_DIR" ]; then
    echo "Creando directorio de salida para CheckM: $OUTPUT_CHECKM_DIR"
    mkdir -p "$OUTPUT_CHECKM_DIR"
fi

# --- Definir el nombre del archivo de log ---
LOG_FILE="$OUTPUT_CHECKM_DIR/${LOG_PREFIX}_checkm.txt"
echo "La salida de CheckM se redirigirá a: $LOG_FILE"

# --- Ejecutar CheckM ---
echo "Ejecutando CheckM en modo lineage_wf..."
# Redirige tanto stdout (1>) como stderr (2>) al mismo archivo de log
checkm lineage_wf -x "$BIN_FORMAT" "$INPUT_BIN_DIR" "$OUTPUT_CHECKM_DIR" -t "$NUM_PROCESSORS" 1> "$LOG_FILE" 2>&1

#mv "$LOG_FILE" $OUTPUT_CHECKM_DIR

if [ $? -ne 0 ]; then
    echo "Error: Falló la ejecución de CheckM. Revisa el archivo de log: $LOG_FILE"
    exit 1
fi


echo "CheckM completado. Resultados en $OUTPUT_CHECKM_DIR. Log en $LOG_FILE"

echo "--- Flujo de trabajo de CheckM completado exitosamente ---"

