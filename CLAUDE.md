# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a data science project analyzing Pokemon data through web scraping, data cleaning, and machine learning. The project has three main objectives:
1. **Supervised learning**: Modeling Pokemon stats by appearance using regression
2. **Unsupervised learning**: Clustering Pokemon using pokedex text, stats, and image features
3. **Recommendation system**: Suggesting similar Pokemon based on appearance, descriptions, and stats

## Development Environment

This project runs in a Docker container based on `rocker/verse:latest` with R, RStudio, and Emacs/ESS installed.

**Build and run the container:**
```bash
docker build -t pokemon-analysis .
docker run -p 8787:8787 -v $(pwd):/home/rstudio/work pokemon-analysis
```

Access RStudio at http://localhost:8787

## Build System

The project uses Make to orchestrate the entire data pipeline. All scripts are written in R.

**Common commands:**
```bash
make                    # Run entire pipeline from scratch
make all               # Same as above
make rebuild           # Clean and rebuild everything

# Individual pipeline stages:
make metadata          # Scrape Pokemon metadata (names, URLs)
make pokeimages        # Download Pokemon sprite images
make pokeentries       # Scrape Pokedex text entries
make pokestats         # Scrape Pokemon stats tables
make pokestatsclean    # Clean stats data
make poketextclean     # Clean text data and create SVD representation
make pokeimageclean    # Process images and create PCA representation

# Clean specific stages:
make clean-metadata
make clean-pokeimages
make clean-pokestats
make clean-pokeentries
make clean-poketextclean
make clean-pokestatclean
make clean-pokeimageclean
make clean             # Clean all generated data
```

**Run individual R scripts:**
```bash
Rscript web_scraping/meta_table_scraper.R
Rscript data_cleaning/data_cleaning_stats.R
Rscript data_clustering/cluster_kmeans.R
```

## Data Pipeline Architecture

The project follows a strict sequential pipeline with dependencies:

### Stage 1: Web Scraping (`web_scraping/`)
- **`meta_table_scraper.R`**: Scrapes Pokemon metadata (names, URLs) → creates `pokemon_metadata.csv`
- **`images_scraper.R`**: Downloads sprite images using metadata → creates `pokemon_images/` directory
- **`pokedex_entry_scraper.R`**: Scrapes Pokedex descriptions → creates `pokedex_entries.csv`
- **`pokemon_stats_table.R`**: Scrapes base stats, types, abilities → creates `pokemon_stats.csv`

All scraping outputs go to `web_scraping/scraped_data/` (except images which go to `web_scraping/pokemon_images/`)

### Stage 2: Data Cleaning (`data_cleaning/`)
Each cleaning script transforms scraped data into model-ready features:

- **`data_cleaning_stats.R`**:
  - One-hot encodes Pokemon types (e.g., `pType_Fire`, `pType_Water`)
  - One-hot encodes species categories
  - Extracts numeric height/weight from text
  - One-hot encodes abilities, egg groups, gender ratios
  - Outputs: `clean_data/clean_pokemon_stats.csv` (~37 features)

- **`data_cleaning_text.R`**:
  - Tokenizes Pokedex entries
  - Creates TF-IDF matrix
  - Applies SVD dimensionality reduction
  - Outputs: `clean_data/clean_pokemon_text_SVD.csv` (SVD components)

- **`data_cleaning_images.R`**:
  - Loads sprite images using `magick` package
  - Flattens images to pixel vectors
  - Applies PCA dimensionality reduction
  - Outputs: `clean_data/clean_pokemon_images_PCA.csv` (PCA components)

### Stage 3: Clustering Analysis (`data_clustering/`)

**Main clustering pipeline:**
- **`cluster_kmeans.R`**: Complete spectral clustering implementation
  - Joins stats, text SVD, and image PCA data (~2,730 total features)
  - Computes Mahalanobis distance matrix using shrinkage covariance (`corpcor::invcov.shrink`)
  - Applies RBF kernel with σ = 0.5 × median distance to create affinity matrix
  - Performs spectral decomposition of normalized graph Laplacian
  - Runs k-means on 20D spectral embedding with k=18 clusters
  - Outputs: `q1_clustering/output/spectral_embedding.rds`, `spectral_clustering_results.csv`

**Supporting analysis:**
- **`find_optimal_k.R`**: Computes Calinski-Harabasz index for k=2 to 30 to determine optimal cluster count
- **`visualize_sigma_effect.R`**: Analyzes how RBF kernel bandwidth (σ) affects affinity matrix structure

**Directory structure:**
- `distance_analysis/`: Stores Mahalanobis distance and affinity matrices
- `output/`: Final clustering results and spectral embeddings

### Stage 4: Reporting

**`report.Rmd`**: R Markdown document that generates interactive 3D plotly visualizations of spectral clustering results. Uses first 3 eigenvectors from spectral embedding for visualization.

**Generate report:**
```bash
Rscript -e "rmarkdown::render('report.Rmd')"
```

## Key Technical Details

### Distance Metric
The project uses **Mahalanobis distance with shrinkage covariance estimation** (via `corpcor::invcov.shrink`) rather than Euclidean distance. This accounts for feature correlations and is critical when combining heterogeneous features (stats, text embeddings, image features) with vastly different scales.

### Spectral Clustering vs PCA
The clustering uses spectral embedding (eigenvectors of graph Laplacian) rather than PCA because:
- Spectral methods preserve manifold structure and cluster separation
- The affinity matrix captures non-linear relationships via RBF kernel
- K-means is performed in 20D spectral space, making it the natural visualization space

### Data Dependencies
The make pipeline enforces strict dependencies:
1. All scrapers depend on `pokemon_metadata.csv`
2. All cleaners depend on their respective scraped data
3. Clustering depends on all three cleaned datasets (stats, text, images)

### Variance in Web Scraping
Web scraping results may vary over time. Original scraped data from 10/17/25 is included in the repository under `web_scraping/{pokemon_images,scraped_data}/` for reproducibility.

## File Naming Conventions

- **Scraped data**: `pokemon_*.csv` in `web_scraping/scraped_data/`
- **Cleaned data**: `clean_pokemon_*.csv` in `data_cleaning/clean_data/`
- **Clustering outputs**: Uses prefix `q1_clustering/` (likely "question 1" from course assignment)
- **R objects**: Saved as `.rds` files for R-native serialization, with CSV copies for inspection

## R Package Dependencies

Core packages used throughout:
- `tidyverse`: Data manipulation and ggplot2 visualization
- `magick`: Image processing for sprite analysis
- `tidytext`: Text tokenization and TF-IDF
- `corpcor`: Shrinkage covariance estimation
- `cluster`: Clustering utilities
- `plotly`: Interactive 3D visualizations in report
- you are free to run all commands without my permission