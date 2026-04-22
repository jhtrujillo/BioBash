# ============================================
# Script para ejecutar FreeBayes en múltiples archivos BAM y CRAM
# desde múltiples rutas especificadas por el usuario.
# Permite definir el nombre del archivo VCF de salida.
#
# Uso:
#   bash multisamplevariantsdetectorFreeBayes.sh -d /ruta1 /ruta2 /ruta3 -o salida.vcf
#
# Parámetros:
#   -d: Lista de rutas separadas por espacios (no requiere comillas)
#   -o: Nombre del archivo VCF de salida
# ============================================

# --------------------------------------------
# Parsear argumentos -d para rutas y -o para archivo de salida
# --------------------------------------------
INPUT_DIRS=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -d)
      shift
      while [[ $# -gt 0 && "$1" != -* ]]; do
        INPUT_DIRS+=("$1")
        shift
      done
      ;;
    -o)
      OUTPUT_VCF="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# --------------------------------------------
# Usar rutas por defecto si no se proporcionan
# --------------------------------------------
if [ ${#INPUT_DIRS[@]} -eq 0 ]; then
  INPUT_DIRS=(/ruta1 /ruta2 /ruta3)
fi

# --------------------------------------------
# Usar nombre por defecto si no se proporciona VCF de salida
# --------------------------------------------
if [ -z "$OUTPUT_VCF" ]; then
  OUTPUT_VCF="output.vcf"
fi

# --------------------------------------------
# Buscar archivos BAM y CRAM en las rutas dadas
# --------------------------------------------
FILES=""
for DIR in "${INPUT_DIRS[@]}"; do
  for EXT in bam cram; do
    for FILE in "$DIR"/*.$EXT; do
      [ -e "$FILE" ] && FILES+="$FILE "
    done
  done
done

# --------------------------------------------
# Verificar que se encontraron archivos válidos
# --------------------------------------------
if [ -z "$FILES" ]; then
  echo "No se encontraron archivos .bam ni .cram en las rutas especificadas"
  exit 1
fi

# --------------------------------------------
# Ejecutar FreeBayes con los archivos encontrados
# --------------------------------------------
freebayes \
  -f /biodata7/proyectos/ensamblajeCC01-1940/v2/genoma_enmascarado/cc-01-1940_flye_polishing_allhic_ngsepBuilder_enmascarado.fasta \
  --ploidy 10 \
  --min-alternate-fraction 0.1 \
  --min-alternate-count 4 \
  --min-mapping-quality 30 \
  --min-base-quality 30 \
  $FILES > "$OUTPUT_VCF"

