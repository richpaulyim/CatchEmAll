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
spectral_embedding <- readRDS("data_clustering/clustering_results/spectral_embedding.rds")

cat(sprintf("  Loaded: %d Pokemon x %d dimensions\n",
            nrow(spectral_embedding), ncol(spectral_embedding)))

# =============================================================================
# Compute All Clustering Metrics
# =============================================================================

cat(sprintf("\nComputing clustering metrics for k = 2 to %d...\n", k_max))
cat("  Methods: Elbow, Silhouette, Calinski-Harabasz, Gap Statistic\n")

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
# Compute Gap Statistic
# =============================================================================

cat("\nComputing Gap Statistic (this may take a few minutes)...\n")

# Gap statistic with B=50 bootstrap samples
set.seed(42)
gap_stat <- clusGap(spectral_embedding,
                    FUN = kmeans,
                    nstart = 25,
                    K.max = k_max,
                    B = 50,
                    verbose = FALSE)

# Extract gap values and standard errors
gap_values <- gap_stat$Tab[, "gap"]
gap_se <- gap_stat$Tab[, "SE.sim"]

# Find optimal k using the "firstSEmax" method (Tibshirani et al.)
# k is optimal if Gap(k) >= Gap(k+1) - SE(k+1)
optimal_k_gap <- maxSE(gap_stat$Tab[, "gap"], gap_stat$Tab[, "SE.sim"], method = "firstSEmax")

cat(sprintf("  Gap statistic suggests: k = %d\n", optimal_k_gap))

# =============================================================================
# Create Results Table
# =============================================================================

clustering_metrics <- tibble(
  k = 1:k_max,
  wcss = wcss_values,
  silhouette = silhouette_values,
  calinski_harabasz = calinski_values,
  gap = gap_values,
  gap_se = gap_se
)

cat("\n  Clustering metrics summary:\n")
print(clustering_metrics, n = k_max)

# Find optimal k for each method
optimal_k_silhouette <- which.max(silhouette_values)  # Maximize silhouette
optimal_k_calinski <- which.max(calinski_values)      # Maximize CH

cat("\n  Optimal k suggestions:\n")
cat(sprintf("    Gap Statistic: k = %d\n", optimal_k_gap))
cat(sprintf("    Silhouette method: k = %d (score = %.3f)\n",
            optimal_k_silhouette, silhouette_values[optimal_k_silhouette]))
cat(sprintf("    Calinski-Harabasz: k = %d (score = %.2f)\n",
            optimal_k_calinski, calinski_values[optimal_k_calinski]))

# =============================================================================
# Save Results
# =============================================================================

# Create output directory
dir.create("data_clustering/clustering_results", showWarnings = FALSE, recursive = TRUE)

# Save metrics table
saveRDS(clustering_metrics, "data_clustering/clustering_results/clustering_metrics_all.rds")
write_csv(clustering_metrics, "data_clustering/clustering_results/clustering_metrics_all.csv")
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

# 2. Gap Statistic plot
p_gap <- ggplot(clustering_metrics, aes(x = k, y = gap)) +
  geom_line(color = "purple", linewidth = 1) +
  geom_point(color = "purple", size = 3) +
  geom_errorbar(aes(ymin = gap - gap_se, ymax = gap + gap_se),
                width = 0.3, color = "purple", alpha = 0.5) +
  geom_vline(xintercept = optimal_k_gap, linetype = "dashed",
             color = "red", linewidth = 0.8) +
  annotate("text", x = optimal_k_gap, y = max(gap_values),
           label = sprintf("Optimal k = %d", optimal_k_gap),
           hjust = -0.1, color = "red", size = 3.5) +
  labs(
    title = "Gap Statistic",
    subtitle = "Higher gap indicates better clustering - error bars show ±1 SE",
    x = "Number of clusters (k)",
    y = "Gap Statistic"
  ) +
  theme_minimal(base_size = 12) +
  scale_x_continuous(breaks = seq(1, k_max, 2))

# 3. Silhouette plot
p_silhouette <- ggplot(clustering_metrics %>% filter(k >= 2),
                       aes(x = k, y = silhouette)) +
  geom_line(color = "darkgreen", linewidth = 1) +
  geom_point(color = "darkgreen", size = 3) +
  geom_vline(xintercept = 18, linetype = "dashed",
             color = "red", linewidth = 0.8) +
  annotate("text", x = 18, y = max(silhouette_values, na.rm = TRUE),
           label = "Selected k = 18",
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
ggsave("data_clustering/clustering_results/elbow_method_plot.png",
       p_elbow, width = 10, height = 6, dpi = 300)
cat("  Saved: elbow_method_plot.png\n")

ggsave("data_clustering/clustering_results/gap_statistic_plot.png",
       p_gap, width = 10, height = 6, dpi = 300)
cat("  Saved: gap_statistic_plot.png\n")

ggsave("data_clustering/clustering_results/silhouette_plot.png",
       p_silhouette, width = 10, height = 6, dpi = 300)
cat("  Saved: silhouette_plot.png\n")

ggsave("data_clustering/clustering_results/calinski_harabasz_plot.png",
       p_calinski, width = 10, height = 6, dpi = 300)
cat("  Saved: calinski_harabasz_plot.png\n")

# =============================================================================
# Summary
# =============================================================================

cat("\n================================================================================\n")
cat("ANALYSIS COMPLETE\n")
cat("================================================================================\n")
cat("\nRecommendations:\n")
cat(sprintf("  - Gap Statistic suggests: k = %d\n", optimal_k_gap))
cat(sprintf("  - Silhouette suggests: k = %d\n", optimal_k_silhouette))
cat(sprintf("  - Calinski-Harabasz suggests: k = %d\n", optimal_k_calinski))
cat("\nNote: Gap statistic uses Tibshirani's 'firstSEmax' method.\n")
cat("      If silhouette suggests k=2, this may indicate outlier detection.\n")
cat("      Consider using multiple methods and visual inspection of plots.\n")
cat("\nAll results saved to: data_clustering/clustering_results/\n")
