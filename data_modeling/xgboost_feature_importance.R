#!/usr/bin/env Rscript
# XGBoost Feature Importance Analysis
# This script trains XGBoost models for each cluster to identify the most
# important features that distinguish each cluster from others

library(tidyverse)
library(xgboost)

# Create output directory if it doesn't exist
dir.create("data_modeling/modeling_results", recursive = TRUE, showWarnings = FALSE)

# Load combined features (all stats, text SVD, image PCA)
cat("Loading combined features...\n")
combined_features <- read_csv("data_clustering/clustering_results/combined_features.csv",
                              show_col_types = FALSE)

# Load clustering results
cat("Loading clustering results...\n")
clustering_results <- read_csv("data_clustering/clustering_results/spectral_clustering_results.csv",
                               show_col_types = FALSE)

# Merge features with cluster assignments
cat("Merging features with cluster assignments...\n")
data <- combined_features %>%
  inner_join(clustering_results, by = "name")

# Separate features from name and cluster
feature_cols <- setdiff(names(data), c("name", "cluster"))
feature_matrix <- data %>% select(all_of(feature_cols))

# Convert to matrix for XGBoost
X <- as.matrix(feature_matrix)

# Get unique clusters
clusters <- sort(unique(data$cluster))
cat(sprintf("Found %d clusters\n", length(clusters)))

# Store all feature importance results
all_importance <- list()

# For each cluster, train a binary classifier (cluster vs rest)
for (clust in clusters) {
  cat(sprintf("Processing cluster %d...\n", clust))

  # Create binary labels (1 if in cluster, 0 otherwise)
  y <- as.numeric(data$cluster == clust)

  # Skip if cluster is too small or too large
  n_positive <- sum(y == 1)
  if (n_positive < 5 || n_positive > nrow(data) - 5) {
    cat(sprintf("  Skipping cluster %d (extreme size: %d samples)\n", clust, n_positive))
    next
  }

  # Create DMatrix for XGBoost
  dtrain <- xgb.DMatrix(data = X, label = y)

  # Train XGBoost model
  # Using binary logistic objective to predict cluster membership
  params <- list(
    objective = "binary:logistic",
    eval_metric = "auc",
    max_depth = 3,
    eta = 0.1,
    subsample = 0.8,
    colsample_bytree = 0.8,
    min_child_weight = 5
  )

  set.seed(42)  # For reproducibility
  model <- xgb.train(
    params = params,
    data = dtrain,
    nrounds = 50,
    verbose = 0
  )

  # Extract feature importance using gain
  importance <- xgb.importance(model = model)

  # Add cluster information
  importance <- importance %>%
    mutate(cluster = clust) %>%
    select(cluster, feature = Feature, gain = Gain)

  all_importance[[as.character(clust)]] <- importance
}

# Combine all importance scores
cat("Combining feature importance across clusters...\n")
feature_importance_all <- bind_rows(all_importance)

# Get top 10 features per cluster
cat("Extracting top 10 features per cluster...\n")
feature_importance_top10 <- feature_importance_all %>%
  group_by(cluster) %>%
  slice_max(order_by = gain, n = 10, with_ties = FALSE) %>%
  ungroup() %>%
  arrange(cluster, desc(gain))

# Save results
cat("Saving feature importance results...\n")
write_csv(feature_importance_top10, "data_modeling/modeling_results/feature_importance_top10.csv")

# Also save full importance for reference
write_csv(feature_importance_all, "data_modeling/modeling_results/feature_importance_all.csv")

cat("Feature importance analysis complete!\n")
cat(sprintf("Results saved to data_modeling/modeling_results/\n"))
cat(sprintf("  - feature_importance_top10.csv: Top 10 features per cluster\n"))
cat(sprintf("  - feature_importance_all.csv: All features with importance > 0\n"))
