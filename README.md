# BioBash: Bioinformatics Analysis Suite

Una suite integrada para la gestión y ejecución de scripts de bioinformática desarrollados por el equipo BAHS.

## Estructura del Proyecto

- `bin/`: Contiene el ejecutable principal `biobash`.
- `scripts/`: Scripts originales organizados por categorías (mapping, variants, metagenomics, etc.).
- `conf/`: Configuración centralizada para rutas y parámetros de herramientas.
- `lib/`: Librerías internas y cargadores de configuración.
- `logs/`: Directorio para el registro de ejecuciones.

## Instalación Recomendada

Para usar la suit desde cualquier lugar, añade el directorio `bin` a tu PATH:

```bash
export PATH="/Users/estuvar4/Documents/2. software/1. suit_scripts_bahs/bin:$PATH"
```

## Uso Básico

La suit funciona mediante subcomandos basados en categorías y scripts:

```bash
biobash <categoría> <script> [argumentos]
```

### Ejemplos:

1. **Listar categorías:**
   ```bash
   biobash --help
   ```

2. **Listar scripts de una categoría (ej: mapping):**
   ```bash
   biobash mapping --list
   ```

3. **Ejecutar un script de mapeo:**
   ```bash
   biobash mapping mapeo_wgs IND01 ref.fasta ./output 32
   ```

4. **Ejecutar detección de variantes con NGSEP:**
   ```bash
   biobash variants multisamplevariantsdetector -d ./bams -r ref.fasta -o out.vcf
   ```

## Configuración Centralizada

Si las rutas de las herramientas (como el JAR de NGSEP) o los directorios de datos cambian, solo necesitas actualizar el archivo:
`conf/biobash.conf`

## Categorías Disponibles

- **mapping**: Scripts de alineamiento (WGS, Paired, RadSeq, etc.).
- **variants**: Detección y filtrado de variantes (NGSEP, GATK, FreeBayes).
- **metagenomics**: Suite Magneto (CheckM, dREP, Binning).
- **conversion**: Conversión entre formatos BAM y CRAM.
- **utils**: Utilidades generales (indexación, merge, sorting, etc.).
