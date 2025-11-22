# Load clustering results for visualization
clustering_results <- read_csv("data_clustering/clustering_results/spectral_clustering_results.csv",
                               show_col_types = FALSE)
clustering_data <- read_csv("data_clustering/clustering_results/spectral_embedding.csv",
                            show_col_types = FALSE)

# Load XGBoost feature importance results
feature_importance <- read_csv("data_modeling/modeling_results/feature_importance_top10.csv",
                               show_col_types = FALSE)

# Get top 10 features per cluster
top_features_per_cluster <- feature_importance %>%
  group_by(cluster) %>%
  slice_head(n = 10) %>%
  summarize(
    top_features = paste(
      paste0(row_number(), ". ", feature, " (", round(gain, 3), ")"),
      collapse = "<br>"
    ),
    .groups = "drop"
  )

# Apply t-SNE to reduce spectral embedding to 3D for visualization
set.seed(42)  # For reproducibility

# Prepare feature matrix (all spectral embedding dimensions)
feature_matrix <- clustering_data %>%
  select(starts_with("V"))

n_dims <- ncol(feature_matrix)
cat(sprintf("Using full spectral embedding: %d dimensions\n", n_dims))

# Run t-SNE on full spectral embedding - 3D version
tsne_result <- Rtsne(
  feature_matrix,
  dims = 3,
  perplexity = 30,
  verbose = FALSE,
  max_iter = 1000,
  check_duplicates = FALSE
)

# Extract t-SNE coordinates (3D)
tsne_data_3d <- as_tibble(tsne_result$Y) %>%
  rename(TSNE1 = V1, TSNE2 = V2, TSNE3 = V3) %>%
  mutate(name = clustering_results$name)

# Calculate cluster sizes first
cluster_sizes <- clustering_results %>%
  group_by(cluster) %>%
  summarize(cluster_size = n(), .groups = "drop")

# Merge t-SNE projection with cluster assignments and cluster sizes
plot_data <- tsne_data_3d %>%
  left_join(clustering_results, by = "name") %>%
  left_join(cluster_sizes, by = "cluster") %>%
  left_join(top_features_per_cluster, by = "cluster") %>%
  mutate(cluster = factor(cluster))

# Recalculate for legend (with proper column name)
cluster_sizes <- cluster_sizes %>%
  rename(n = cluster_size) %>%
  arrange(cluster)

# Create legend labels with cluster sizes
cluster_labels <- setNames(
  paste0("Cluster ", cluster_sizes$cluster, " (n=", cluster_sizes$n, ")"),
  cluster_sizes$cluster
)

# Define high-contrast color palette for 18 clusters
high_contrast_colors <- c(
  "#e6194b", "#3cb44b", "#ffe119", "#4363d8", "#f58231",
  "#911eb4", "#46f0f0", "#f032e6", "#bcf60c", "#fabebe",
  "#008080", "#e6beff", "#9a6324", "#fffac8", "#800000",
  "#aaffc3", "#808000", "#ffd8b1"
)

# Create interactive 3D plotly plot
p <- plot_ly(
  data = plot_data,
  x = ~TSNE1,
  y = ~TSNE2,
  z = ~TSNE3,
  color = ~cluster,
  colors = high_contrast_colors,
  text = ~paste0(name, "<br>Cluster ", cluster, " (n=", cluster_size, ")"),
  customdata = ~top_features,
  type = "scatter3d",
  mode = "markers",
  marker = list(
    size = 5,
    opacity = 0.8,
    line = list(
      color = "rgba(0, 0, 0, 0.5)",
      width = 1
    )
  ),
  hovertemplate = paste(
    "<b>%{text}</b><br>",
    "<br><b>Top 10 Features (XGBoost Gain):</b><br>",
    "%{customdata}<br>",
    "<extra></extra>"
  )
) %>%
  layout(
    title = list(
      text = sprintf("Pokemon Spectral Clustering - 3D t-SNE Visualization (k=18)<br><sub>t-SNE projection of %dD spectral embedding</sub>", n_dims),
      font = list(size = 16),
      y = 0.98,
      x = 0.05,
      xanchor = "left",
      yanchor = "top"
    ),
    scene = list(
      xaxis = list(
        title = "t-SNE Dimension 1",
        gridcolor = "#E5E5E5",
        showgrid = TRUE,
        zeroline = FALSE,
        backgroundcolor = "#F8F8F8"
      ),
      yaxis = list(
        title = "t-SNE Dimension 2",
        gridcolor = "#E5E5E5",
        showgrid = TRUE,
        zeroline = FALSE,
        backgroundcolor = "#F8F8F8"
      ),
      zaxis = list(
        title = "t-SNE Dimension 3",
        gridcolor = "#E5E5E5",
        showgrid = TRUE,
        zeroline = FALSE,
        backgroundcolor = "#F8F8F8"
      ),
      camera = list(
        eye = list(x = 1.5, y = 1.5, z = 1.3)
      )
    ),
    paper_bgcolor = "white",
    margin = list(t = 80, b = 50, l = 50, r = 200),
    legend = list(
      title = list(text = "<b>Clusters</b>"),
      orientation = "v",
      x = 1.02,
      y = 1,
      font = list(size = 11)
    ),
    hovermode = "closest"
  ) %>%
  config(
    displayModeBar = TRUE,
    displaylogo = FALSE,
    modeBarButtonsToRemove = c("select2d", "lasso2d"),
    toImageButtonOptions = list(
      format = "png",
      filename = "pokemon_clustering_3d",
      height = 1000,
      width = 1400,
      scale = 2
    )
  )

# Update trace names to include cluster sizes
for (i in seq_along(p$x$data)) {
  trace_cluster <- as.character(unique(p$x$data[[i]]$legendgroup))
  if (trace_cluster %in% names(cluster_labels)) {
    p$x$data[[i]]$name <- cluster_labels[trace_cluster]
  }
}
