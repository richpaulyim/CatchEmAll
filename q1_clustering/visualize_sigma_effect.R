library(tidyverse)

# =============================================================================
# Load Mahalanobis Distance Matrix
# =============================================================================

cat("Loading Mahalanobis distance matrix...\n")
mahal_dist_matrix <- readRDS("q1_clustering/distance_analysis/mahalanobis_distance_matrix.rds")

# Get upper triangle of distances (avoid duplicates and diagonal)
distances <- mahal_dist_matrix[upper.tri(mahal_dist_matrix)]

cat(sprintf("Number of pairwise distances: %d\n", length(distances)))
cat(sprintf("Distance range: [%.2f, %.2f]\n", min(distances), max(distances)))
cat(sprintf("Median distance: %.2f\n", median(distances)))

# =============================================================================
# Test Different Sigma Values
# =============================================================================

# Create a range of sigma values around the median
median_dist <- median(distances)
sigma_multipliers <- c(0.5, 1:5)
sigma_values <- median_dist * sigma_multipliers

cat("\nTesting sigma values:\n")
for (s in sigma_values) {
  cat(sprintf("  sigma = %.2f (%.2fx median)\n", s, s/median_dist))
}

# Function to compute RBF affinity
rbf_affinity <- function(dist, sigma) {
  exp(-dist^2 / (2 * sigma^2))
}

# Compute affinities for each sigma
affinity_data <- tibble()
for (sigma in sigma_values) {
  affinities <- rbf_affinity(distances, sigma)

  temp_df <- tibble(
    sigma = sigma,
    affinity = affinities,
    distance = distances
  )

  affinity_data <- bind_rows(affinity_data, temp_df)
}

# Calculate range for each sigma and create labels
affinity_ranges <- affinity_data %>%
  group_by(sigma) %>%
  summarise(
    min_aff = min(affinity),
    max_aff = max(affinity),
    len_aff = max(affinity)-min(affinity),
    .groups = "drop"
  ) %>%
  mutate(
    sigma_label = sprintf("σ = %.2f (%.1fx) [%.3f-%.3f](width %.3f)",
                         sigma, sigma/median_dist, min_aff, max_aff, len_aff)
  )

# Join back to affinity_data
affinity_data <- affinity_data %>%
  left_join(affinity_ranges %>% select(sigma, sigma_label), by = "sigma")

# Order sigma_label by sigma value
affinity_data <- affinity_data %>%
  mutate(sigma_label = fct_reorder(sigma_label, sigma))

# =============================================================================
# Create Visualizations
# =============================================================================

cat("\nCreating visualizations...\n")

# 1. Original distance distribution
p1 <- ggplot(tibble(distance = distances), aes(x = distance)) +
  geom_histogram(bins = 50, fill = "steelblue", alpha = 0.7) +
  geom_vline(xintercept = median_dist, color = "red", linetype = "dashed", size = 1) +
  annotate("text", x = median_dist, y = Inf, label = "Median",
           vjust = 1.5, hjust = -0.1, color = "red", size = 4) +
  labs(
    title = "Distribution of Mahalanobis Distances",
    x = "Distance",
    y = "Count"
  ) +
  theme_minimal(base_size = 12)

# 2. Affinity distributions for different sigma values (combined on one plot)
# Calculate minimum affinity (bottom of support) for each sigma
min_affinities <- affinity_data %>%
  group_by(sigma_label, sigma) %>%
  summarise(min_affinity = min(affinity), .groups = "drop")

p2 <- ggplot(affinity_data, aes(x = affinity, color = sigma_label, fill = sigma_label)) +
  geom_density(aes(y = after_stat(density)), alpha = 0.3, linewidth = 1) +
  geom_segment(data = min_affinities,
               aes(x = min_affinity, xend = min_affinity,
                   y = 0, yend = 500, color = sigma_label),
               linewidth = 0.8, linetype = "solid") +
  labs(
    title = "Affinity Distributions for Different Sigma Values",
    subtitle = "RBF Kernel: exp(-d²/(2σ²)) - Vertical marks show minimum support",
    x = "Affinity (similarity)",
    y = "Density (area = 1)",
    color = "Sigma Value",
    fill = "Sigma Value"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom") +
  guides(color = guide_legend(ncol = 2), fill = guide_legend(ncol = 2))


# 4. Summary statistics table showing sparsification effects
sparsity_summary <- affinity_data %>%
  group_by(sigma_label, sigma) %>%
  summarise(
    mean_affinity = mean(affinity),
    median_affinity = median(affinity),
    pct_above_0.5 = mean(affinity > 0.5) * 100,
    pct_above_0.1 = mean(affinity > 0.1) * 100,
    pct_above_0.01 = mean(affinity > 0.01) * 100,
    .groups = "drop"
  ) %>%
  arrange(sigma)

cat("\nSparsification Analysis:\n")
cat("(Shows % of edges that would be kept under different thresholds)\n\n")
print(sparsity_summary, n = Inf)

# =============================================================================
# Save Plots
# =============================================================================

cat("\nSaving plots...\n")
dir.create("q1_clustering/distance_analysis/sigma_analysis", showWarnings = FALSE, recursive = TRUE)

ggsave("q1_clustering/distance_analysis/sigma_analysis/distance_distribution.png",
       p1, width = 10, height = 6, dpi = 300)
cat("  Saved: distance_distribution.png\n")

ggsave("q1_clustering/distance_analysis/sigma_analysis/affinity_distributions.png",
       p2, width = 10, height = 6, dpi = 300)
cat("  Saved: affinity_distributions.png\n")

# Save summary table
write_csv(sparsity_summary, "q1_clustering/distance_analysis/sigma_analysis/sparsity_summary.csv")
cat("  Saved: sparsity_summary.csv\n")

cat("\nDone! Check q1_clustering/distance_analysis/sigma_analysis/ for results.\n")
