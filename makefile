# Pokemon Analysis Pipeline Makefile
# Complete end-to-end pipeline from web scraping to report generation

# =============================================================================
# Directory Definitions
# =============================================================================
SCRAPING_DIR = data_scraping
CLEANING_DIR = data_cleaning
CLUSTERING_DIR = data_clustering
MODELING_DIR = data_modeling

# Data directories
IMAGE_DIR = $(SCRAPING_DIR)/pokemon_images
SCRAPED_DATA_DIR = $(SCRAPING_DIR)/scraped_data
CLEAN_DATA_DIR = $(CLEANING_DIR)/clean_data
CLUSTERING_RESULTS_DIR = $(CLUSTERING_DIR)/clustering_results
MODELING_RESULTS_DIR = $(MODELING_DIR)/modeling_results

# =============================================================================
# Script Definitions
# =============================================================================
# Scraping scripts
METADATA_SCRIPT = $(SCRAPING_DIR)/meta_table_scraper.R
IMAGE_SCRIPT = $(SCRAPING_DIR)/images_scraper.R
STATS_TABLE_SCRIPT = $(SCRAPING_DIR)/pokemon_stats_table.R
POKEDEX_ENTRY_SCRIPT = $(SCRAPING_DIR)/pokedex_entry_scraper.R

# Cleaning scripts
STAT_CLEAN_SCRIPT = $(CLEANING_DIR)/data_cleaning_stats.R
TEXT_CLEAN_SCRIPT = $(CLEANING_DIR)/data_cleaning_text.R
IMAGE_CLEAN_SCRIPT = $(CLEANING_DIR)/data_cleaning_images.R
TSNE_CLEAN_SCRIPT = $(CLEANING_DIR)/create_tsne_plot.R

# Clustering scripts
CLUSTER_KMEANS_SCRIPT = $(CLUSTERING_DIR)/cluster_kmeans.R
FIND_OPTIMAL_K_SCRIPT = $(CLUSTERING_DIR)/find_optimal_k.R
VISUALIZE_SIGMA_SCRIPT = $(CLUSTERING_DIR)/visualize_sigma_effect.R

# Modeling scripts
FEATURE_IMPORTANCE_SCRIPT = $(MODELING_DIR)/xgboost_feature_importance.R
TSNE_VIZ_SCRIPT = $(MODELING_DIR)/tsne_visualization.R

# =============================================================================
# Data File Definitions
# =============================================================================
# Scraped data
METADATA_CSV = $(SCRAPED_DATA_DIR)/pokemon_metadata.csv
POKE_STATS_CSV = $(SCRAPED_DATA_DIR)/pokemon_stats.csv
POKE_ENTRIES_CSV = $(SCRAPED_DATA_DIR)/pokedex_entries.csv
IMAGE_TIMESTAMP = $(IMAGE_DIR)/.timestamp

# Clean data
CLEAN_STAT_CSV = $(CLEAN_DATA_DIR)/clean_pokemon_stats.csv
CLEAN_TEXT_CSV = $(CLEAN_DATA_DIR)/clean_pokemon_text_SVD.csv
CLEAN_IMAGE_CSV = $(CLEAN_DATA_DIR)/clean_pokemon_images_PCA.csv
TSNE_CLEAN_PLOT = $(CLEAN_DATA_DIR)/tsne_clean_data.png

# Clustering results
SPECTRAL_RESULTS = $(CLUSTERING_RESULTS_DIR)/spectral_clustering_results.csv
SPECTRAL_EMBEDDING = $(CLUSTERING_RESULTS_DIR)/spectral_embedding.csv
COMBINED_FEATURES = $(CLUSTERING_RESULTS_DIR)/combined_features.csv
DISTANCE_PLOT = $(CLUSTERING_RESULTS_DIR)/distance_distribution.png
AFFINITY_PLOT = $(CLUSTERING_RESULTS_DIR)/affinity_distributions.png
ELBOW_PLOT = $(CLUSTERING_RESULTS_DIR)/elbow_method_plot.png
GAP_PLOT = $(CLUSTERING_RESULTS_DIR)/gap_statistic_plot.png
CH_PLOT = $(CLUSTERING_RESULTS_DIR)/calinski_harabasz_plot.png
SILHOUETTE_PLOT = $(CLUSTERING_RESULTS_DIR)/silhouette_plot.png

# Modeling results
FEATURE_IMPORTANCE = $(MODELING_RESULTS_DIR)/feature_importance_top10.csv

# =============================================================================
# Main Targets
# =============================================================================
.PHONY: all report scraping cleaning clustering modeling \
        clean clean-scraping clean-cleaning clean-clustering clean-modeling clean-report \
        rebuild help

# Default: generate the complete report
all: report

# Generate HTML report
report: $(SPECTRAL_RESULTS) $(FEATURE_IMPORTANCE) $(TSNE_VIZ_SCRIPT) \
        $(DISTANCE_PLOT) $(AFFINITY_PLOT) $(ELBOW_PLOT) $(GAP_PLOT) \
        $(CH_PLOT) $(SILHOUETTE_PLOT) $(TSNE_CLEAN_PLOT)
	@echo "=========================================="
	@echo "Generating report.html..."
	@echo "=========================================="
	Rscript -e "rmarkdown::render('report.Rmd')"
	@echo ""
	@echo "✓ Report generated successfully!"
	@echo ""

# =============================================================================
# Stage 1: Web Scraping
# =============================================================================
scraping: $(METADATA_CSV) $(IMAGE_TIMESTAMP) $(POKE_ENTRIES_CSV) $(POKE_STATS_CSV)

# Step 1.1: Scrape metadata (creates CSV with URLs, names, etc.)
$(METADATA_CSV): $(METADATA_SCRIPT)
	@echo "Scraping Pokemon metadata..."
	Rscript $(METADATA_SCRIPT)

# Step 1.2: Download images (depends on metadata)
$(IMAGE_TIMESTAMP): $(IMAGE_SCRIPT) $(METADATA_CSV)
	@echo "Downloading Pokemon images..."
	Rscript $(IMAGE_SCRIPT)
	@touch $(IMAGE_TIMESTAMP)

# Step 1.3: Scrape Pokedex entries (depends on metadata)
$(POKE_ENTRIES_CSV): $(POKEDEX_ENTRY_SCRIPT) $(METADATA_CSV)
	@echo "Scraping Pokedex entries..."
	Rscript $(POKEDEX_ENTRY_SCRIPT)

# Step 1.4: Scrape Pokemon stats (depends on metadata)
$(POKE_STATS_CSV): $(STATS_TABLE_SCRIPT) $(METADATA_CSV)
	@echo "Scraping Pokemon stats..."
	Rscript $(STATS_TABLE_SCRIPT)

# =============================================================================
# Stage 2: Data Cleaning
# =============================================================================
cleaning: $(CLEAN_STAT_CSV) $(CLEAN_TEXT_CSV) $(CLEAN_IMAGE_CSV) $(TSNE_CLEAN_PLOT)

# Step 2.1: Clean stats data
$(CLEAN_STAT_CSV): $(STAT_CLEAN_SCRIPT) $(METADATA_CSV) $(POKE_STATS_CSV)
	@echo "Cleaning Pokemon stats data..."
	Rscript $(STAT_CLEAN_SCRIPT)

# Step 2.2: Clean text data and create SVD representation
$(CLEAN_TEXT_CSV): $(TEXT_CLEAN_SCRIPT) $(METADATA_CSV) $(POKE_ENTRIES_CSV)
	@echo "Cleaning Pokemon text data and creating SVD representation..."
	Rscript $(TEXT_CLEAN_SCRIPT)

# Step 2.3: Clean image data and create PCA representation
$(CLEAN_IMAGE_CSV): $(IMAGE_CLEAN_SCRIPT) $(IMAGE_TIMESTAMP)
	@echo "Processing Pokemon images and creating PCA representation..."
	Rscript $(IMAGE_CLEAN_SCRIPT)

# Step 2.4: Create t-SNE visualization of combined clean data
$(TSNE_CLEAN_PLOT): $(TSNE_CLEAN_SCRIPT) $(CLEAN_STAT_CSV) $(CLEAN_TEXT_CSV) $(CLEAN_IMAGE_CSV)
	@echo "Creating t-SNE visualization of clean data..."
	Rscript $(TSNE_CLEAN_SCRIPT)

# =============================================================================
# Stage 3: Clustering Analysis
# =============================================================================
clustering: $(SPECTRAL_RESULTS) $(DISTANCE_PLOT) $(ELBOW_PLOT)

# Step 3.1: Run spectral clustering (creates main results and combined features)
$(SPECTRAL_RESULTS) $(SPECTRAL_EMBEDDING) $(COMBINED_FEATURES): \
    $(CLUSTER_KMEANS_SCRIPT) $(CLEAN_STAT_CSV) $(CLEAN_TEXT_CSV) $(CLEAN_IMAGE_CSV)
	@echo "Running spectral clustering analysis..."
	Rscript $(CLUSTER_KMEANS_SCRIPT)

# Step 3.2: Visualize sigma effect (creates distance and affinity plots)
$(DISTANCE_PLOT) $(AFFINITY_PLOT): \
    $(VISUALIZE_SIGMA_SCRIPT) $(SPECTRAL_RESULTS)
	@echo "Analyzing sigma effect and creating distance/affinity plots..."
	Rscript $(VISUALIZE_SIGMA_SCRIPT)

# Step 3.3: Find optimal k (creates elbow, gap, CH, silhouette plots)
$(ELBOW_PLOT) $(GAP_PLOT) $(CH_PLOT) $(SILHOUETTE_PLOT): \
    $(FIND_OPTIMAL_K_SCRIPT) $(SPECTRAL_EMBEDDING)
	@echo "Finding optimal number of clusters..."
	Rscript $(FIND_OPTIMAL_K_SCRIPT)

# =============================================================================
# Stage 4: Feature Importance Modeling
# =============================================================================
modeling: $(FEATURE_IMPORTANCE)

# Step 4.1: Run XGBoost feature importance analysis
$(FEATURE_IMPORTANCE): $(FEATURE_IMPORTANCE_SCRIPT) \
                       $(SPECTRAL_RESULTS) $(COMBINED_FEATURES)
	@echo "Running XGBoost feature importance analysis..."
	Rscript $(FEATURE_IMPORTANCE_SCRIPT)

# =============================================================================
# Convenience Targets
# =============================================================================
# Run entire pipeline from scratch (including report)
rebuild: clean-scraping clean-cleaning clean-clustering clean-modeling clean-report
	@echo ""
	@echo "=========================================="
	@echo "Building complete project from scratch..."
	@echo "=========================================="
	@echo ""
	@$(MAKE) scraping
	@$(MAKE) cleaning
	@$(MAKE) clustering
	@$(MAKE) modeling
	@$(MAKE) report
	@echo ""
	@echo "=========================================="
	@echo "✓ Complete rebuild finished!"
	@echo "=========================================="
	@echo ""

# Run just the analysis pipeline (no cleaning, assumes data exists)
pipeline: scraping cleaning clustering modeling
	@echo ""
	@echo "=========================================="
	@echo "✓ Pipeline finished!"
	@echo "=========================================="
	@echo ""

# =============================================================================
# Clean Targets
# =============================================================================
# Clean scraped data
clean-scraping:
	@echo "Cleaning scraped data..."
	rm -rf $(SCRAPED_DATA_DIR)/*.csv
	rm -rf $(IMAGE_DIR)/*.png
	rm -f $(IMAGE_TIMESTAMP)

# Clean processed data
clean-cleaning:
	@echo "Cleaning processed data..."
	rm -rf $(CLEAN_DATA_DIR)/*.csv
	rm -f $(TSNE_CLEAN_PLOT)

# Clean clustering outputs
clean-clustering:
	@echo "Cleaning clustering outputs..."
	rm -rf $(CLUSTERING_RESULTS_DIR)/*

# Clean modeling outputs
clean-modeling:
	@echo "Cleaning modeling outputs..."
	rm -rf $(MODELING_RESULTS_DIR)/*

# Clean generated report
clean-report:
	@echo "Cleaning generated report..."
	rm -f report.html report.knit.md

# Clean everything (all generated files)
clean: clean-report clean-modeling clean-clustering clean-cleaning
	@echo "✓ All generated files cleaned!"

# =============================================================================
# Help
# =============================================================================
help:
	@echo "Pokemon Analysis Makefile"
	@echo "=========================="
	@echo ""
	@echo "Main targets:"
	@echo "  all        - Generate complete report (default)"
	@echo "  report     - Generate report.html"
	@echo "  rebuild    - Build complete project from scratch"
	@echo "  pipeline   - Run analysis pipeline (assumes data exists)"
	@echo ""
	@echo "Pipeline stages:"
	@echo "  scraping   - Scrape Pokemon data from pokemondb.net"
	@echo "  cleaning   - Clean and process scraped data"
	@echo "  clustering - Run spectral clustering analysis"
	@echo "  modeling   - Run XGBoost feature importance"
	@echo ""
	@echo "Clean targets:"
	@echo "  clean-scraping   - Remove scraped data"
	@echo "  clean-cleaning   - Remove cleaned data"
	@echo "  clean-clustering - Remove clustering outputs"
	@echo "  clean-modeling   - Remove modeling outputs"
	@echo "  clean-report     - Remove generated report"
	@echo "  clean            - Remove all generated files"
	@echo ""
	@echo "Directory structure:"
	@echo "  data_scraping/    - Web scraping scripts and outputs"
	@echo "  data_cleaning/    - Data cleaning scripts and outputs"
	@echo "  data_clustering/  - Clustering analysis scripts and outputs"
	@echo "  data_modeling/    - Modeling scripts and outputs"
	@echo ""
