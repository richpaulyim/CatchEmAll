library(tidyverse)
library(cluster)

# =============================================================================
# Find Optimal Number of Clusters Using Multiple Methods
# =============================================================================
# This script analyzes the spectral embedding to determine optimal k
# Methods: Elbow, Silhouette, Calinski-Harabasz
# =============================================================================

cat("================================================================================\n")
cat("OPTIMAL CLUSTER COUNT ANALYSIS\n")
cat("================================================================================\n")

# Parameters
k_max <- 20  # Maximum number of clusters to test

cat(sprintf("\nLoading spectral embedding...\n"))

# Load spectral embedding from cluster_kmeans.R output
spectral_embedding <- readRDS("q1_clustering/output/spectral_embedding.rds")

cat(sprintf("  Loaded: %d Pokemon x %d dimensions\n",
            nrow(spectral_embedding), ncol(spectral_embedding)))

# =============================================================================
# Compute All Clustering Metrics
# =============================================================================

cat(sprintf("\nComputing clustering metrics for k = 2 to %d...\n", k_max))
cat("  Methods: Elbow, Silhouette, Calinski-Harabasz\n")

# Set seed for reproducibility
set.seed(42)

# Initialize storage for all metrics
wcss_values <- numeric(k_max)
silhouette_values <- numeric(k_max)
calinski_values <- numeric(k_max)

# For k=1, only WCSS is defined
wcss_values[1] <- sum(scale(spectral_embedding, scale = FALSE)^2)
silhouette_values[1] <- NA
calinski_values[1] <- NA

# Compute all metrics for k = 2 to k_max
for (k in 2:k_max) {
  # Run k-means
  kmeans_temp <- kmeans(spectral_embedding, centers = k, nstart = 25, iter.max = 100)

  # 1. Elbow method: Within-cluster sum of squares
  wcss_values[k] <- kmeans_temp$tot.withinss

  # 2. Silhouette analysis
  sil <- silhouette(kmeans_temp$cluster, dist(spectral_embedding))
  silhouette_values[k] <- mean(sil[, 3])  # Average silhouette width

  # 3. Calinski-Harabasz index
  # CH = [SS_between / (k-1)] / [SS_within / (n-k)]
  ss_between <- kmeans_temp$betweenss
  ss_within <- kmeans_temp$tot.withinss
  n <- nrow(spectral_embedding)
  calinski_values[k] <- (ss_between / (k - 1)) / (ss_within / (n - k))

  if (k %% 5 == 0) {
    cat(sprintf("    k = %d: WCSS = %.2f, Silhouette = %.3f, CH = %.2f\n",
                k, wcss_values[k], silhouette_values[k], calinski_values[k]))
  }
}

cat("  All methods computation complete!\n")

# =============================================================================
# Create Results Table
# =============================================================================

clustering_metrics <- tibble(
  k = 1:k_max,
  wcss = wcss_values,
  silhouette = silhouette_values,
  calinski_harabasz = calinski_values
)

cat("\n  Clustering metrics summary:\n")
print(clustering_metrics, n = k_max)

# Find optimal k for each method
optimal_k_silhouette <- which.max(silhouette_values)  # Maximize silhouette
optimal_k_calinski <- which.max(calinski_values)      # Maximize CH

cat("\n  Optimal k suggestions:\n")
cat(sprintf("    Silhouette method: k = %d (score = %.3f)\n",
            optimal_k_silhouette, silhouette_values[optimal_k_silhouette]))
cat(sprintf("    Calinski-Harabasz: k = %d (score = %.2f)\n",
            optimal_k_calinski, calinski_values[optimal_k_calinski]))

# =============================================================================
# Save Results
# =============================================================================

# Create output directory
dir.create("q1_clustering/output/optimal_k_analysis", showWarnings = FALSE, recursive = TRUE)

# Save metrics table
saveRDS(clustering_metrics, "q1_clustering/output/optimal_k_analysis/clustering_metrics_all.rds")
write_csv(clustering_metrics, "q1_clustering/output/optimal_k_analysis/clustering_metrics_all.csv")
cat("\n  Saved: clustering_metrics_all.rds and .csv\n")

# =============================================================================
# Create Visualization Plots
# =============================================================================

cat("\nCreating visualization plots...\n")

# 1. Elbow plot
p_elbow <- ggplot(clustering_metrics, aes(x = k, y = wcss)) +
  geom_line(color = "steelblue", linewidth = 1) +
  geom_point(color = "steelblue", size = 3) +
  labs(
    title = "Elbow Method",
    subtitle = "Look for the 'elbow' where WCSS decreases slowly",
    x = "Number of clusters (k)",
    y = "Within-Cluster Sum of Squares (WCSS)"
  ) +
  theme_minimal(base_size = 12) +
  scale_x_continuous(breaks = seq(1, k_max, 2))

# 2. Silhouette plot
p_silhouette <- ggplot(clustering_metrics %>% filter(k >= 2),
                       aes(x = k, y = silhouette)) +
  geom_line(color = "darkgreen", linewidth = 1) +
  geom_point(color = "darkgreen", size = 3) +
  geom_vline(xintercept = optimal_k_silhouette, linetype = "dashed",
             color = "red", linewidth = 0.8) +
  annotate("text", x = optimal_k_silhouette, y = max(silhouette_values, na.rm = TRUE),
           label = sprintf("Optimal k = %d", optimal_k_silhouette),
           hjust = -0.1, color = "red", size = 3.5) +
  labs(
    title = "Silhouette Analysis",
    subtitle = "Higher is better - measures cluster cohesion and separation",
    x = "Number of clusters (k)",
    y = "Average Silhouette Width"
  ) +
  theme_minimal(base_size = 12) +
  scale_x_continuous(breaks = seq(2, k_max, 2))

# 3. Calinski-Harabasz plot
p_calinski <- ggplot(clustering_metrics %>% filter(k >= 2),
                     aes(x = k, y = calinski_harabasz)) +
  geom_line(color = "darkorange", linewidth = 1) +
  geom_point(color = "darkorange", size = 3) +
  geom_vline(xintercept = optimal_k_calinski, linetype = "dashed",
             color = "red", linewidth = 0.8) +
  annotate("text", x = optimal_k_calinski, y = max(calinski_values, na.rm = TRUE),
           label = sprintf("Optimal k = %d", optimal_k_calinski),
           hjust = -0.1, color = "red", size = 3.5) +
  labs(
    title = "Calinski-Harabasz Index",
    subtitle = "Higher is better - ratio of between to within cluster variance",
    x = "Number of clusters (k)",
    y = "Calinski-Harabasz Index"
  ) +
  theme_minimal(base_size = 12) +
  scale_x_continuous(breaks = seq(2, k_max, 2))

# Save plots
ggsave("q1_clustering/output/optimal_k_analysis/elbow_method_plot.png",
       p_elbow, width = 10, height = 6, dpi = 300)
cat("  Saved: elbow_method_plot.png\n")

ggsave("q1_clustering/output/optimal_k_analysis/silhouette_plot.png",
       p_silhouette, width = 10, height = 6, dpi = 300)
cat("  Saved: silhouette_plot.png\n")

ggsave("q1_clustering/output/optimal_k_analysis/calinski_harabasz_plot.png",
       p_calinski, width = 10, height = 6, dpi = 300)
cat("  Saved: calinski_harabasz_plot.png\n")

# =============================================================================
# Summary
# =============================================================================

cat("\n================================================================================\n")
cat("ANALYSIS COMPLETE\n")
cat("================================================================================\n")
cat("\nRecommendations:\n")
cat(sprintf("  - Silhouette suggests: k = %d\n", optimal_k_silhouette))
cat(sprintf("  - Calinski-Harabasz suggests: k = %d\n", optimal_k_calinski))
cat("\nNote: If silhouette suggests k=2, this may indicate outlier detection.\n")
cat("      Consider using Calinski-Harabasz or visual inspection of elbow plot.\n")
cat("\nAll results saved to: q1_clustering/output/optimal_k_analysis/\n")
