#!/bin/bash
# ============================================================
# QIIME2: Soil Metagenome Analysis — влияние керосина на микробное сообщество
# Автор: Слепов Константин Олегович
# Данные: чужой проект PRJNA786393
# Дата: октябрь 2025
# ============================================================

# ------------------------------------------------------------
# 0. Подготовка окружения
# ------------------------------------------------------------
conda activate qiime2-amplicon-2024.10
mkdir -p results/qza results/qzv results/soil_core_metrics_results

# ------------------------------------------------------------
# 1. Контроль качества: FastQC
# ------------------------------------------------------------
# Пример анализа одного образца (одноконцевые прочтения)
fastqc data/raw_reads/SRR17307258_1.fastq -o results/fastqc_results/

# ------------------------------------------------------------
# 2. Импорт данных в формат Qiime2
# ------------------------------------------------------------
qiime tools import \
  --type 'SampleData[SequencesWithQuality]' \
  --input-path data/soil_metadata_for_input.tsv \
  --output-path results/qza/soil_reads.qza \
  --input-format SingleEndFastqManifestPhred33V2

# ------------------------------------------------------------
# 3. DADA2: фильтрация, коррекция и удаление химер
# ------------------------------------------------------------
qiime dada2 denoise-single \
    --i-demultiplexed-seqs results/qza/soil_reads.qza \
    --p-trim-left 25 \
    --p-trunc-len 200 \
    --p-max-ee 3 \
    --p-n-threads 20 \
    --p-pooling-method "pseudo" \
    --p-chimera-method "consensus" \
    --p-min-fold-parent-over-abundance 4 \
    --o-table results/qza/soil_ASV_table.qza \
    --o-representative-sequences results/qza/soil_rep_seq.qza \
    --o-denoising-stats results/qza/soil_reads.dada2.stats.qza

# ------------------------------------------------------------
# 4. Визуализация статистики фильтрации
# ------------------------------------------------------------
qiime metadata tabulate \
    --m-input-file results/qza/soil_reads.dada2.stats.qza \
    --o-visualization results/qzv/soil_reads.dada2.stats.qzv

# ------------------------------------------------------------
# 5. Таксономическая классификация ампликонов
# ------------------------------------------------------------
qiime feature-classifier classify-sklearn \
    --i-classifier data/2022.10.backbone.v4.nb.sklearn-1.4.2.qza \
    --i-reads results/qza/soil_rep_seq.qza \
    --o-classification results/qza/soil_taxonomy.qza \
    --p-n-jobs 16

# ------------------------------------------------------------
# 6. Визуализация таксономии
# ------------------------------------------------------------
qiime taxa barplot \
    --i-table results/qza/soil_ASV_table.qza \
    --i-taxonomy results/qza/soil_taxonomy.qza \
    --m-metadata-file data/soil_metadata_full.tsv \
    --o-visualization results/qzv/soil_taxonomy_barplot.qzv

# ------------------------------------------------------------
# 7. Построение филогенетического дерева
# ------------------------------------------------------------
qiime phylogeny align-to-tree-mafft-fasttree \
    --i-sequences results/qza/soil_rep_seq.qza \
    --o-alignment results/qza/aligned_soil_rep_seq.qza \
    --o-masked-alignment results/qza/masked_aligned_soil_rep_seq.qza \
    --o-tree results/qza/soil_unrooted_tree.qza \
    --o-rooted-tree results/qza/soil_rooted_tree.qza

# ------------------------------------------------------------
# 8. Альфа- и бета-разнообразие
# ------------------------------------------------------------
qiime diversity core-metrics-phylogenetic \
    --i-phylogeny results/qza/soil_rooted_tree.qza \
    --i-table results/qza/soil_ASV_table.qza \
    --p-sampling-depth 4809 \
    --m-metadata-file data/soil_metadata_full.tsv \
    --output-dir results/soil_core_metrics_results

# ------------------------------------------------------------
# 9. Анализ индекса Шеннона
# ------------------------------------------------------------
qiime diversity alpha-group-significance \
    --i-alpha-diversity results/soil_core_metrics_results/shannon_vector.qza \
    --m-metadata-file data/soil_single_metadata.tsv \
    --o-visualization results/soil_core_metrics_results/soil_shannon_significance.qzv

# ------------------------------------------------------------
# 10. Конец пайплайна
# ------------------------------------------------------------
echo "Анализ завершён. Результаты сохранены в results/qzv/, results/qza/, и results/soil_core_metrics_results/"
