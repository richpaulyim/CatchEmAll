library(tidyverse)
library(Rtsne)

# =============================================================================
# Create t-SNE Visualization of Clean Combined Data
# =============================================================================
# This script creates a 2D t-SNE visualization of all combined features
# (stats + text SVD + image PCA) to show data structure before clustering
# =============================================================================

cat("================================================================================\n")
cat("t-SNE VISUALIZATION OF CLEAN DATA\n")
cat("================================================================================\n")

# Load all three cleaned datasets
cat("\nLoading cleaned data...\n")
stats_data <- read_csv("data_cleaning/clean_data/clean_pokemon_stats.csv",
                       show_col_types = FALSE)
text_data <- read_csv("data_cleaning/clean_data/clean_pokemon_text_SVD.csv",
                      show_col_types = FALSE)
image_data <- read_csv("data_cleaning/clean_data/clean_pokemon_images_PCA.csv",
                       show_col_types = FALSE)

cat(sprintf("  Stats data: %d rows, %d columns\n", nrow(stats_data), ncol(stats_data)))
cat(sprintf("  Text data: %d rows, %d columns\n", nrow(text_data), ncol(text_data)))
cat(sprintf("  Image data: %d rows, %d columns\n", nrow(image_data), ncol(image_data)))

# Combine all datasets
cat("\nCombining datasets...\n")
combined_data <- stats_data %>%
  inner_join(text_data, by = "name") %>%
  inner_join(image_data, by = "name")

cat(sprintf("  Combined: %d rows, %d columns\n", nrow(combined_data), ncol(combined_data)))

# Prepare feature matrix (exclude name column)
feature_matrix <- combined_data %>%
  select(-name) %>%
  as.matrix()

# Run t-SNE (2D for visualization)
cat("\nRunning t-SNE dimensionality reduction...\n")
cat("  Parameters: dims=2, perplexity=30, max_iter=1000\n")

set.seed(42)
tsne_result <- Rtsne(
  feature_matrix,
  dims = 2,
  perplexity = 30,
  verbose = TRUE,
  max_iter = 1000,
  check_duplicates = FALSE
)

# Extract t-SNE coordinates
tsne_coords <- as_tibble(tsne_result$Y) %>%
  rename(TSNE1 = V1, TSNE2 = V2) %>%
  mutate(name = combined_data$name)

cat("\nt-SNE projection complete!\n")

# Create visualization
cat("\nCreating visualization...\n")

p <- ggplot(tsne_coords, aes(x = TSNE1, y = TSNE2)) +
  geom_point(alpha = 0.6, size = 1.5, color = "steelblue") +
  labs(
    title = "t-SNE Visualization of Combined Clean Data (2,730 features)",
    subtitle = "Stats + Text SVD + Image PCA features",
    x = "t-SNE Dimension 1",
    y = "t-SNE Dimension 2"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 10, color = "gray40"),
    panel.grid.minor = element_blank()
  )

# Save plot
output_file <- "data_cleaning/clean_data/tsne_clean_data.png"
ggsave(output_file, p, width = 7, height = 4, dpi = 300)

cat(sprintf("\n  Saved: %s\n", output_file))

cat("\n================================================================================\n")
cat("t-SNE VISUALIZATION COMPLETE\n")
cat("================================================================================\n")
