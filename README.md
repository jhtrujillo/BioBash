# BioBash: Bioinformatics Analysis Suite

Una suite integrada para la gestión y ejecución de scripts de bioinformática desarrollados por el equipo BAHS.

## Estructura del Proyecto

- `bin/`: Contiene el ejecutable principal `biobash`.
- `scripts/`: Scripts originales organizados por categorías.
- `conf/`: Configuración centralizada (`biobash.conf`).
- `lib/`: Librerías internas y cargador de configuración.
- `logs/`: Registro de ejecuciones.

## Instalación

Añade el directorio `bin` a tu PATH para usar `biobash` desde cualquier lugar:
```bash
export PATH="/Users/estuvar4/Documents/2. software/1. suit_scripts_bahs/bin:$PATH"
```

---

## 📖 Tutorial de Uso

La suite se ejecuta siguiendo este formato general:
```bash
biobash <categoría> <script> [argumentos]
```

### 1. Mapeo (`mapping`)
Scripts para alinear lecturas (FASTQ) a un genoma de referencia.

*   **`mapeo_wgs`**: Mapeo de Whole Genome Sequencing (lecturas pareadas).
    ```bash
    biobash mapping mapeo_wgs <ID_Muestra> <ref.fasta> <dir_salida> <num_procesadores>
    ```
*   **`mapeo_gsb`**: Mapeo con opciones de multi-mapping o filtrado único.
    ```bash
    biobash mapping mapeo_gsb <ID_Muestra> <ref.fasta> <dir_salida> <num_procesadores> [--unique] [--mapq 20]
    ```
*   **`mapeo_radseq`**: Mapeo especializado para datos de RAD-seq.
    ```bash
    biobash mapping mapeo_radseq <ID_Muestra> <ref.fasta> <dir_salida> <num_procesadores>
    ```

### 2. Detección de Variantes (`variants`)
Herramientas para identificar SNPs, Indels y genotipos.

*   **`multisamplevariantsdetector`**: Detección masiva usando NGSEP.
    ```bash
    biobash variants multisamplevariantsdetector -d <dir_bams> -r <ref.fasta> -o <salida.vcf> [-p ploidia]
    ```
*   **`findvariants`**: Detección en una muestra individual.
    ```bash
    biobash variants findvariants -b <muestra.bam> -o <salida.vcf> [-k vcf_conocido]
    ```
*   **`merge_vcfs`**: Combina múltiples archivos VCF en uno solo.
    ```bash
    biobash variants merge_vcfs -i <dir_vcfs> -o <fusionado.vcf>
    ```

### 3. Metagenómica (`metagenomics`)
Flujos de trabajo para análisis de comunidades microbianas (Suite Magneto).

*   **`magneto_checkM`**: Evaluación de calidad de MAGs (bins).
    ```bash
    biobash metagenomics magneto_checkM -f fa -i <dir_bins> -o <salida_checkm> -t <hilos> -l <id_log>
    ```
*   **`magneto_single_binning`**: Proceso de binning para muestras individuales.
    ```bash
    biobash metagenomics magneto_single_binning <ensamblaje.fasta> <bam_mapeo> <dir_salida> <hilos>
    ```

### 4. Conversión de Formatos (`conversion`)
Optimización de almacenamiento de archivos de alineamiento.

*   **`bam_to_cram`**: Convierte BAM (pesado) a CRAM (ligero).
    ```bash
    biobash conversion bam_to_cram -i <entrada.bam> -r <ref.fasta> -t <hilos> -d <dir_destino>
    ```
*   **`cram_to_bam`**: Restaura un archivo CRAM a BAM.
    ```bash
    biobash conversion cram_to_bam -i <entrada.cram> -r <ref.fasta> -t <hilos> -d <dir_destino>
    ```

### 5. Utilidades y Mantenimiento (`utils`)
Herramientas de soporte para el día a día.

*   **`check_bams`**: Verifica la integridad y existencia de archivos BAM masivamente.
    ```bash
    biobash utils check_bams <archivo_lista_individuos.txt> <dir_bams>
    ```
*   **`sort_bam`**: Ordena archivos BAM por coordenadas genómicas.
    ```bash
    biobash utils sort_bam <entrada.bam> <hilos> <mem_por_hilo>
    ```
*   **`create_bwa_indexes`**: Genera índices de BWA para una referencia.
    ```bash
    biobash utils create_bwa_indexes <referencia.fasta>
    ```

---

## Configuración Centralizada

Todas las herramientas leen sus rutas base y parámetros globales de:
`conf/biobash.conf`

Si necesitas cambiar la ubicación de la base de datos de datos de WGS o el archivo de consecutivos, edita ese archivo una sola vez.
