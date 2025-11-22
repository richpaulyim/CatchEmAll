# CatchEmAll: Pokemon Data Science

(Full report is `report.html`---this will be built from scratch using `make rebuild`.)

Unsupervised machine learning analysis of Pokemon using spectral clustering on multimodal data (stats, Pokedex text, sprite images). Built for BIOS 611 at UNC-CH.

## Project Overview

This project discovers natural groupings of 948 Pokemon by combining three data sources:

- **Base stats** (HP, Attack, Defense, etc.) - one-hot encoded categorical + numeric features
- **Pokedex text** - TF-IDF matrix compressed with SVD for semantic embeddings
- **Sprite images** - Pixel data compressed with PCA for visual features

**Key methods:**
- Mahalanobis distance with shrinkage covariance (handles 2,730 heterogeneous features)
- RBF kernel + graph Laplacian for spectral embedding
- K-means clustering (k=18) selected via Calinski-Harabasz + Silhouette analysis
- XGBoost for interpretable feature importance per cluster
- Interactive 3D t-SNE visualization

## Quick Start

**1. Build the Docker environment:**
```bash
docker build -t pokemon-analysis .
docker run -p 8787:8787 -v $(pwd):/home/rstudio/work pokemon-analysis
```

**2. Inside the container, run the full pipeline:**
```bash
make              # Generates report.html (uses existing scraped data)
make rebuild      # Cleans everything and rebuilds from scratch
```

**3. View the report:**
- Open `report.html` in your browser
- Explore the interactive 3D clustering visualization

## Makefile Usage

The Makefile orchestrates a 4-stage pipeline. Each stage depends on the previous:

### Main Targets

```bash
make              # Generate report (default - uses cached data)
make all          # Same as make
make rebuild      # Clean all outputs and rebuild from scratch
make help         # Show all available commands
```

### Pipeline Stages (run independently or automatically via `make`)

```bash
make scraping     # Stage 1: Web scrape Pokemon data
make cleaning     # Stage 2: Process stats/text/images
make clustering   # Stage 3: Spectral clustering + optimal k analysis
make modeling     # Stage 4: XGBoost feature importance
make report       # Generate final HTML report
```

**Note:** The full pipeline (`make rebuild`) takes ~10-15 minutes. Individual stages:
- `scraping`: ~5-10 min (downloads 985 Pokemon images; 948 used in final analysis after inner join)
- `cleaning`: ~2-3 min (PCA/SVD computations)
- `clustering`: ~3-5 min (includes Gap statistic with 50 bootstrap samples)
- `modeling`: ~1 min
- `report`: ~30 sec (knits RMarkdown)

### Cleaning Targets (remove generated files)

```bash
make clean                # Remove all generated files except scraped data
make clean-scraping       # Remove scraped CSVs and images
make clean-cleaning       # Remove cleaned data (PCA/SVD outputs)
make clean-clustering     # Remove clustering results
make clean-modeling       # Remove feature importance files
make clean-report         # Remove report.html
```

**Tip:** To regenerate only the report with updated commentary:
```bash
make clean-report && make report
```

## Data Source

All data web scraped from [pokemondb.net](https://pokemondb.net). Original scraped data (985 Pokemon) preserved in `data_scraping/` for reproducibility. Final analysis uses 948 Pokemon after inner joining stats, text, and image data by Pokemon name. (Note: Web scraping results may vary over time as the database is updated)

## Directory Structure

```
.
├── data_scraping/           # Stage 1: Web scraping scripts + outputs
│   ├── *.R                  # 4 scraping scripts (metadata, images, stats, text)
│   ├── scraped_data/        # Raw CSV files (metadata, stats, Pokedex entries)
│   └── pokemon_images/      # 985 downloaded sprite images
│
├── data_cleaning/           # Stage 2: Data preprocessing scripts + outputs
│   ├── *.R                  # 4 cleaning scripts (stats, text SVD, image PCA, t-SNE plot)
│   └── clean_data/          # Clean CSV files (~2,730 features) + t-SNE plot
│
├── data_clustering/         # Stage 3: Clustering analysis scripts + outputs
│   ├── *.R                  # 3 scripts (spectral clustering, optimal k, sigma analysis)
│   └── clustering_results/  # Spectral embeddings, cluster assignments, plots
│
├── data_modeling/           # Stage 4: Modeling scripts + outputs
│   ├── *.R                  # 2 scripts (XGBoost importance, 3D t-SNE viz)
│   └── modeling_results/    # Feature importance CSVs
│
├── web_screenshots/         # Screenshots embedded in report
├── Makefile                 # Pipeline automation (read this for dependencies!)
├── report.Rmd               # RMarkdown source for analysis report
├── report.html              # Generated HTML report (8.1 MB)
└── README.md
```

**Key principle:** Each directory contains scripts + a single results folder (max 1 level deep).

## Pipeline Dependencies

The Makefile encodes all dependencies. In brief:

1. **Scraping**: `meta_table_scraper.R` runs first → other scrapers depend on metadata
2. **Cleaning**: Each cleaner reads scraped data → produces clean CSVs + t-SNE plot
3. **Clustering**: `cluster_kmeans.R` combines all clean data → spectral clustering results
4. **Modeling**: `xgboost_feature_importance.R` reads clustering results → feature importance
5. **Report**: `report.Rmd` sources all plots + runs `tsne_visualization.R` → `report.html`

Run `make -n` to see the full dependency graph without executing.

## Technical Summary

- **Input**: 948 Pokemon × 2,730 features (stats + text SVD + image PCA)
- **Distance**: Mahalanobis with shrinkage covariance (`corpcor::invcov.shrink`)
- **Kernel**: RBF with σ = 0.5 × median distance (maximizes affinity distribution width)
- **Spectral Embedding**: 21D space selected via intelligent criteria:
  - Spectral gap analysis (largest eigenvalue gap in first 100 dimensions)
  - k+log(k) heuristic (21 dimensions for k=18 clusters)
  - Final selection: max(spectral_gap, k+log(k)) = 21 eigenvectors
- **Clustering**: K-means with k=18 in 21D spectral space (Calinski-Harabasz + Silhouette agreement)
- **Interpretation**: XGBoost binary classifiers + 3D t-SNE visualization

## R Package Dependencies

All required packages are pre-installed in the Docker container:
- `tidyverse` - Data manipulation and visualization
- `corpcor` - Shrinkage covariance estimation
- `cluster` - Clustering utilities and silhouette analysis
- `plotly` - Interactive 3D visualizations
- `magick` - Image processing for sprite analysis
- `tidytext` - Text tokenization and TF-IDF
- `Rtsne` - t-SNE dimensionality reduction
- `xgboost` - Gradient boosting for feature importance
- `rvest` - Web scraping from pokemondb.net

## Author

Richard Paul Yim - rpyim@unc.edu

