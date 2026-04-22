ind=$1

# Rutas y nombres
REF="/biodata7/proyectos/ensamblajeCC01-1940/v2/genoma_enmascarado/cc-01-1940_flye_polishing_allhic_ngsepBuilder_enmascarado.fasta"
GATK_SCRIPT="/biodata4/proyectos/scripts/gatk_parallel_pipeline.sh"
BAM_SOURCE="../all_bams/scaffold_65961_temp/"
LOG_DIR="logs"
OUT_DIR="ind_${ind}"

# Crear carpetas si no existen
mkdir -p "$LOG_DIR" "$OUT_DIR"

# Limpieza: borra todo excepto carpetas y scripts
find . -maxdepth 1 -type f ! -name "*.sh" -exec rm -f {} \;

# Copiar los primeros N BAMs
ls "$BAM_SOURCE"/*.bam | head -n "$ind" | parallel -j1 "cp {} ."

# Indexar BAMs si falta el .bai
echo "Indexando BAMs..."
for bam in *_all_sorted.bam; do
	  [ -f "${bam}.bai" ] || samtools index "$bam"
  done

  # --- GATK ---
#echo ">> Ejecutando GATK con ${ind} muestras..."
#{ time bash "$GATK_SCRIPT" \
#	    --ref "$REF" \
#	      --ploidy 10 \
#	        --threads 80 \
#		  --bam-dir . \
#		    --output-vcf all_gatk_variants_num_ind_${ind}.vcf.gz; } \
#		      2>&1 | tee "${LOG_DIR}/gatk_ind_${ind}.log"

  # --- FreeBayes ---
  echo ">> Ejecutando FreeBayes..."
  { time freebayes \
	    -f "$REF" \
      --ploidy 10 \
        --min-mapping-quality 30 \
		  --min-base-quality 30 \
		    *.bam > all_freebyes_variants_num_ind_${ind}.vcf; } \
		      2>&1 | tee "${LOG_DIR}/freebayes_ind_${ind}.log"

  # --- NGSEP ---
 # echo ">> Ejecutando NGSEP..."
 # { time java -jar /biodata1/biotools/ngsep/NGSEPcore/NGSEPcore_5.0.0.jar MultisampleVariantsDetector \
#	    -r "$REF" \
#	      -o all_ngsep_variants_num_ind_${ind}.vcf \
#	        -ploidy 10 \
#		  -minMQ 30 \
#		    -maxBaseQS 30 \
#		      *.bam; } \
#		        2>&1 | tee "${LOG_DIR}/ngsep_ind_${ind}.log"

  # Mover VCFs al directorio correspondiente
  mv *.vcf* "$OUT_DIR"

  # --- Extraer y mostrar tiempos finales ---
  echo -e "\n========== TIEMPOS DE EJECUCIÓN (real) EN MINUTOS =========="

  for tool in gatk freebayes ngsep; do
	    tiempo=$(grep "^real" ${LOG_DIR}/${tool}_ind_${ind}.log | awk '{ split($2, t, "m"); gsub(",", ".", t[2]); minutos = t[1] + t[2]/60; printf "%.2f", minutos }')
	      echo "${tool^^}: ${tiempo} minutos"
      done

