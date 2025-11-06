library(tidyverse)
library(corpcor)
library(cluster)

# =============================================================================
# Read in cleaned data from all three sources
# =============================================================================

cat("Reading cleaned data files...\n")

# Read stats data (name is column 38)
stats_data <- read_csv("data_cleaning/clean_data/clean_pokemon_stats.csv")
cat(sprintf("  Stats data: %d Pokemon x %d features\n",
            nrow(stats_data), ncol(stats_data) - 1))

# Read text SVD data
text_data <- read_csv("data_cleaning/clean_data/clean_pokemon_text_SVD.csv")
cat(sprintf("  Text SVD data: %d Pokemon x %d components\n",
            nrow(text_data), ncol(text_data) - 1))

# Read image PCA data
image_data <- read_csv("data_cleaning/clean_data/clean_pokemon_images_PCA.csv")
cat(sprintf("  Image PCA data: %d Pokemon x %d components\n",
            nrow(image_data), ncol(image_data) - 1))

# =============================================================================
# Join all datasets by Pokemon name
# =============================================================================

cat("\nJoining datasets by Pokemon name...\n")

# Combine all three datasets
combined_data <- stats_data %>%
  inner_join(text_data, by = "name") %>%
  inner_join(image_data, by = "name")

cat(sprintf("  Combined data: %d Pokemon x %d total features\n",
            nrow(combined_data), ncol(combined_data) - 1))

# Extract pokemon names for later use
pokemon_names <- combined_data$name

# Create feature matrix (exclude name column)
feature_matrix <- combined_data %>%
  select(-name) %>%
  as.matrix()

rownames(feature_matrix) <- pokemon_names

cat(sprintf("\nFeature matrix dimensions: %d x %d\n",
            nrow(feature_matrix), ncol(feature_matrix)))

# =============================================================================
# Calculate Mahalanobis Distance Matrix
# =============================================================================

cat("\nCalculating Mahalanobis distance matrix...\n")

# Center the data (subtract column means)
cat("  Centering the feature matrix...\n")
centered_data <- scale(feature_matrix, center = TRUE, scale = FALSE)

# Get number of Pokemon
n_pokemon <- nrow(centered_data)
shrink_cov <- invcov.shrink(feature_matrix)

# Get number of Pokemon
n_pokemon <- nrow(centered_data)

# Calculate pairwise Mahalanobis distances using vectorized approach
cat("Computing pairwise distances using vectorized matrix operations...\n")

# Compute M = X * Sigma_inv * X^T
# This gives us the inner products in the Mahalanobis metric
mahal_pokemon <- centered_data %*% shrink_cov%*% t(centered_data)

# Extract diagonal (these are x_i^T * Sigma_inv * x_i for each i)
diag_M <- diag(mahal_pokemon)

# Compute squared distance matrix (vectorized computation):
mahal_dist_sq <- outer(diag_M, diag_M, "+") - 2 * mahal_pokemon

# Take square root to get distances (set any small negative values to 0 first)
mahal_dist_sq[mahal_dist_sq < 0] <- 0
mahal_dist_matrix <- sqrt(mahal_dist_sq)

# Add row and column names
rownames(mahal_dist_matrix) <- pokemon_names
colnames(mahal_dist_matrix) <- pokemon_names

cat("\nMahalanobis distance matrix computed successfully!\n")
cat(sprintf("  Matrix dimensions: %d x %d\n",
            nrow(mahal_dist_matrix), ncol(mahal_dist_matrix)))
cat(sprintf("  Distance range: [%.2f, %.2f]\n",
            min(mahal_dist_matrix), max(mahal_dist_matrix)))

# =============================================================================
# Apply RBF Kernel to Create Affinity Matrix for Spectral Clustering
# =============================================================================

cat("\nApplying RBF kernel to create affinity matrix...\n")

# Calculate sigma as 0.5 * median distance
distances_vector <- mahal_dist_matrix[upper.tri(mahal_dist_matrix)]
median_dist <- median(distances_vector)
sigma <- 0.5 * median_dist

cat(sprintf("  Median distance: %.2f\n", median_dist))
cat(sprintf("  Sigma (0.5 × median): %.2f\n", sigma))

# Apply RBF kernel: W[i,j] = exp(-d²[i,j] / (2 * sigma²))
affinity_matrix <- exp(-mahal_dist_matrix^2 / (2 * sigma^2))

# Ensure diagonal is 1 (self-similarity)
diag(affinity_matrix) <- 1

# Add row and column names
rownames(affinity_matrix) <- pokemon_names
colnames(affinity_matrix) <- pokemon_names

cat("\nAffinity matrix computed successfully!\n")
cat(sprintf("  Matrix dimensions: %d x %d\n",
            nrow(affinity_matrix), ncol(affinity_matrix)))
cat(sprintf("  Affinity range: [%.4f, %.4f]\n",
            min(affinity_matrix), max(affinity_matrix)))
cat(sprintf("  Mean affinity: %.4f\n", mean(affinity_matrix)))
cat(sprintf("  Median affinity: %.4f\n", median(affinity_matrix)))

# =============================================================================
# Save results
# =============================================================================

cat("\nSaving distance and affinity matrices...\n")
# Create distance_analysis directory
dir.create("q1_clustering/distance_analysis", 
           showWarnings = FALSE, 
           recursive = TRUE)

# Save the combined feature matrix
write_csv(combined_data, "q1_clustering/distance_analysis/combined_features.csv")
cat("  Saved: q1_clustering/distance_analysis/combined_features.csv\n")

# Save Mahalanobis distance matrix
saveRDS(mahal_dist_matrix, "q1_clustering/distance_analysis/mahalanobis_distance_matrix.rds")
cat("  Saved: q1_clustering/distance_analysis/mahalanobis_distance_matrix.rds\n")

# Also save as CSV for easier inspection
write.csv(mahal_dist_matrix, "q1_clustering/distance_analysis/mahalanobis_distance_matrix.csv")
cat("  Saved: q1_clustering/distance_analysis/mahalanobis_distance_matrix.csv\n")

# Save affinity matrix (for spectral clustering)
saveRDS(affinity_matrix, "q1_clustering/distance_analysis/affinity_matrix.rds")
cat("  Saved: q1_clustering/distance_analysis/affinity_matrix.rds\n")

# Also save as CSV
write.csv(affinity_matrix, "q1_clustering/distance_analysis/affinity_matrix.csv")
cat("  Saved: q1_clustering/distance_analysis/affinity_matrix.csv\n")

cat("\nDone saving matrices!\n")

# =============================================================================
# Spectral Clustering on Weighted Affinity Matrix
# =============================================================================

cat("\n" , rep("=", 80), "\n", sep = "")
cat("SPECTRAL CLUSTERING\n")
cat(rep("=", 80), "\n", sep = "")

# Parameters for spectral clustering
n_eigenvectors <- 20  # Number of eigenvectors to use for embedding
n_clusters <- 18      # Final number of clusters (determined from analysis)

cat(sprintf("\nParameters:\n"))
cat(sprintf("  Number of eigenvectors: %d\n", n_eigenvectors))
cat(sprintf("  Number of clusters: %d\n", n_clusters))

# =============================================================================
# Step 1: Compute Degree Matrix
# =============================================================================

cat("\nStep 1: Computing degree matrix...\n")

# Degree matrix: D[i,i] = sum of all edge weights for node i
degree_vector <- rowSums(affinity_matrix)

cat(sprintf("  Degree range: [%.2f, %.2f]\n", min(degree_vector), max(degree_vector)))
cat(sprintf("  Mean degree: %.2f\n", mean(degree_vector)))

# Create diagonal degree matrix (as vector for efficient computation)
D_inv_sqrt <- 1 / sqrt(degree_vector)

# Handle any potential division by zero (shouldn't happen with affinity matrix)
D_inv_sqrt[!is.finite(D_inv_sqrt)] <- 0

# =============================================================================
# Step 2: Compute Normalized Graph Laplacian
# =============================================================================

cat("\nStep 2: Computing normalized graph Laplacian...\n")
cat("  L = I - D^(-1/2) * W * D^(-1/2)\n")

# Compute D^(-1/2) * W * D^(-1/2) efficiently
# This is equivalent to: (D_inv_sqrt[i] * W[i,j] * D_inv_sqrt[j])
normalized_affinity <- sweep(affinity_matrix, 1, D_inv_sqrt, "*")
normalized_affinity <- sweep(normalized_affinity, 2, D_inv_sqrt, "*")

# Laplacian: L = I - normalized_affinity
laplacian <- diag(nrow(affinity_matrix)) - normalized_affinity

cat("  Laplacian computed successfully!\n")

# =============================================================================
# Step 3: Compute Eigenvectors
# =============================================================================

cat("\nStep 3: Computing eigenvectors of the Laplacian...\n")
cat(sprintf("  Computing %d smallest eigenvectors...\n", n_eigenvectors + 1))

# Compute eigenvectors corresponding to smallest eigenvalues
# We compute n_eigenvectors + 1 because the first one (eigenvalue ≈ 0) is trivial
eigen_result <- eigen(laplacian, symmetric = TRUE)

# Eigenvalues are returned in decreasing order, so we want the LAST ones (smallest)
n_total <- length(eigen_result$values)
indices <- (n_total - n_eigenvectors):n_total

eigenvalues <- eigen_result$values[indices]
eigenvectors <- eigen_result$vectors[, indices]

cat(sprintf("  Smallest %d eigenvalues:\n", n_eigenvectors + 1))
cat(sprintf("    Range: [%.6f, %.6f]\n", min(eigenvalues), max(eigenvalues)))
cat(sprintf("    First eigenvalue (should be ≈ 0): %.6f\n", eigenvalues[length(eigenvalues)]))

# Remove the trivial eigenvector (corresponding to smallest eigenvalue)
# The last eigenvalue is the smallest, so we remove the last column
spectral_embedding <- eigenvectors[, 1:n_eigenvectors]

# Add Pokemon names as rownames
rownames(spectral_embedding) <- pokemon_names

cat(sprintf("\nSpectral embedding created!\n"))
cat(sprintf("  Dimensions: %d Pokemon x %d dimensions\n",
            nrow(spectral_embedding), ncol(spectral_embedding)))

# =============================================================================
# Step 4: Run K-means on Spectral Embedding
# =============================================================================
# Note: Optimal k was determined using find_optimal_k.R script
# Based on Calinski-Harabasz analysis, k=18 provides optimal clustering

cat(sprintf("\nStep 4: Running k-means clustering with k = %d...\n", n_clusters))

# Set seed for reproducibility
set.seed(42)

# Run k-means clustering
kmeans_result <- kmeans(spectral_embedding,
                        centers = n_clusters,
                        nstart = 25,  # Multiple random starts
                        iter.max = 100)

cat(sprintf("  K-means converged in %d iterations\n", kmeans_result$iter))
cat(sprintf("  Total within-cluster sum of squares: %.2f\n",
            kmeans_result$tot.withinss))
cat(sprintf("  Between-cluster sum of squares: %.2f\n",
            kmeans_result$betweenss))
cat(sprintf("  Ratio (between/total): %.2f%%\n",
            100 * kmeans_result$betweenss / kmeans_result$totss))

# Create results dataframe
clustering_results <- tibble(
  name = pokemon_names,
  cluster = kmeans_result$cluster
)

# Show cluster sizes
cluster_sizes <- clustering_results %>%
  count(cluster) %>%
  arrange(cluster)

cat("\nCluster sizes:\n")
print(cluster_sizes)

# =============================================================================
# Save Spectral Clustering Results
# =============================================================================

cat("\nSaving spectral clustering results...\n")

# Create output directory
dir.create("q1_clustering/output", showWarnings = FALSE, recursive = TRUE)

# Save spectral embedding
saveRDS(spectral_embedding, "q1_clustering/output/spectral_embedding.rds")
cat("  Saved: q1_clustering/output/spectral_embedding.rds\n")

write.csv(spectral_embedding, "q1_clustering/output/spectral_embedding.csv")
cat("  Saved: q1_clustering/output/spectral_embedding.csv\n")

# Save clustering results
saveRDS(clustering_results, "q1_clustering/output/spectral_clustering_results.rds")
cat("  Saved: q1_clustering/output/spectral_clustering_results.rds\n")

write_csv(clustering_results, "q1_clustering/output/spectral_clustering_results.csv")
cat("  Saved: q1_clustering/output/spectral_clustering_results.csv\n")

# Save full kmeans object
saveRDS(kmeans_result, "q1_clustering/output/kmeans_model.rds")
cat("  Saved: q1_clustering/output/kmeans_model.rds\n")

cat("\n" , rep("=", 80), "\n", sep = "")
cat("SPECTRAL CLUSTERING COMPLETE!\n")
cat(rep("=", 80), "\n", sep = "")
cat(sprintf("\nFinal clustering: k = %d clusters\n", n_clusters))
cat(sprintf("Clustered %d Pokemon into %d groups\n", nrow(clustering_results), n_clusters))
cat(sprintf("Between/total variance ratio: %.2f%%\n",
            100 * kmeans_result$betweenss / kmeans_result$totss))
cat("\nResults saved to q1_clustering/output/\n")
cat("  - spectral_embedding.rds/csv (20D embedding)\n")
cat("  - spectral_clustering_results.rds/csv (cluster assignments)\n")
cat("  - kmeans_model.rds (full k-means model)\n")
cat("\nNote: To analyze optimal k, run: Rscript q1_clustering/find_optimal_k.R\n")
