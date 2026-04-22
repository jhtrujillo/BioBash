# BioBash: Bioinformatics Analysis Suite

An integrated suite for managing and executing bioinformatics scripts developed by the BAHS team.

## Project Structure

- `bin/`: Contains the main executable `biobash`.
- `scripts/`: Original scripts organized by categories.
- `conf/`: Centralized configuration (`biobash.conf`).
- `lib/`: Internal libraries and configuration loader.
- `logs/`: Execution logs directory.

## Installation

Add the `bin` directory to your PATH to use `biobash` from anywhere:
```bash
export PATH="/Users/estuvar4/Documents/2. software/1. suit_scripts_bahs/bin:$PATH"
```

---

## 📖 Usage Tutorial

The suite is executed following this general format:
```bash
biobash <category> <script> [arguments]
```

### 1. Mapping (`mapping`)
Scripts to align reads (FASTQ) to a reference genome.

*   **`mapping_wgs`**: Whole Genome Sequencing mapping (paired-end reads).
    ```bash
    biobash mapping mapping_wgs <Sample_ID> <ref.fasta> <output_dir> <threads>
    ```
*   **`mapping_gsb`**: Mapping with multi-mapping or unique filtering options.
    ```bash
    biobash mapping mapping_gsb <Sample_ID> <ref.fasta> <output_dir> <threads> [--unique] [--mapq 20]
    ```
*   **`mapping_radseq`**: Specialized mapping for RAD-seq data.
    ```bash
    biobash mapping mapping_radseq <Sample_ID> <ref.fasta> <output_dir> <threads>
    ```

### 2. Variant Discovery (`variants`)
Tools to identify SNPs, Indels, and genotypes.

*   **`multisamplevariantsdetector`**: Bulk detection using NGSEP.
    ```bash
    biobash variants multisample_variant_detector -d <bam_dir> -r <ref.fasta> -o <output.vcf> [-p ploidy]
    ```
*   **`find_variants`**: Detection in an individual sample.
    ```bash
    biobash variants find_variants -b <sample.bam> -o <output.vcf> [-k known_vcf]
    ```
*   **`merge_vcfs`**: Combines multiple VCF files into one.
    ```bash
    biobash variants merge_vcfs -i <vcf_dir> -o <merged.vcf>
    ```

### 3. Metagenomics (`metagenomics`)
Workflows for microbial community analysis (Magneto Suite).

*   **`magneto_checkM`**: Quality assessment of MAGs (bins).
    ```bash
    biobash metagenomics magneto_checkM -f fa -i <bins_dir> -o <checkm_output> -t <threads> -l <log_id>
    ```
*   **`magneto_single_binning`**: Binning process for individual samples.
    ```bash
    biobash metagenomics magneto_single_binning <assembly.fasta> <mapping_bam> <output_dir> <threads>
    ```

### 4. Format Conversion (`conversion`)
Optimization of alignment file storage.

*   **`bam_to_cram`**: Converts BAM (heavy) to CRAM (light).
    ```bash
    biobash conversion bam_to_cram -i <input.bam> -r <ref.fasta> -t <threads> -d <dest_dir>
    ```
*   **`cram_to_bam`**: Restores a CRAM file to BAM.
    ```bash
    biobash conversion cram_to_bam -i <input.cram> -r <ref.fasta> -t <threads> -d <dest_dir>
    ```

### 5. Utilities & Maintenance (`utils`)
Support tools for day-to-day tasks.

*   **`check_bams`**: Bulk verifies the integrity and existence of BAM files.
    ```bash
    biobash utils check_bams <sample_list.txt> <bam_dir>
    ```
*   **`sort_bam`**: Sorts BAM files by genomic coordinates.
    ```bash
    biobash utils sort_bam <input.bam> <threads> <mem_per_thread>
    ```
*   **`create_bwa_indexes`**: Generates BWA indexes for a reference.
    ```bash
    biobash utils create_bwa_indexes <reference.fasta>
    ```

---

## Centralized Configuration

All tools read their base paths and global parameters from:
`conf/biobash.conf`

If you need to change the location of the WGS data database or the consecutive file, edit this file once.
