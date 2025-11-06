library(magick)
library(ggplot2)
library(stringr)

# Get all PNG files from the pokemon_images directory
image_files <- list.files("web_scraping/pokemon_images",
                         pattern = "\\.png$",
                         full.names = TRUE)

# Initialize list to store image data in memory
cat("Processing images and building data frame in memory...\n")
pokemon_names <- character(length(image_files))
pixel_data_list <- list()

# Process all images
for (i in 1:length(image_files)) {
  img_path <- image_files[i]
  pokemon_name <- tools::file_path_sans_ext(basename(img_path))
  # Capitalize name to match other datasets
  pokemon_name <- str_to_title(pokemon_name)
  pokemon_names[i] <- pokemon_name

  # Read and apply transformations
  img <- image_read(img_path) %>%
    image_trim() %>%
    image_resize("200x200") %>%
    image_extent("200x200", gravity = "center", color = "white") %>%
    image_convert(colorspace = "sRGB")

  # Convert to RGB matrix and flatten
  img_array <- as.integer(image_data(img, channels = "rgb"))
  img_vector <- as.vector(img_array)

  # Store in list
  pixel_data_list[[i]] <- img_vector

  cat("Processed:", pokemon_name, "\n")

  # Clean up memory periodically
  if (i %% 50 == 0) {
    rm(img, img_array, img_vector)
    gc()
  }
}

cat("\nTotal images processed:", length(image_files), "\n")

# Convert list to matrix
cat("Converting to matrix for PCA...\n")
pixel_matrix <- do.call(rbind, pixel_data_list)
rownames(pixel_matrix) <- pokemon_names

# Clean up the list to free memory
rm(pixel_data_list)
gc()

# Perform PCA on the image data
cat("\nPerforming PCA on image data...\n")

# Perform PCA directly on pixel matrix
pca_result <- prcomp(pixel_matrix, center = TRUE, scale. = FALSE)

cat("PCA complete. Total principal components:", ncol(pca_result$x), "\n")

# Create PCA-transformed dataset with all principal components
cat("\nCreating PCA-transformed dataset...\n")
pca_scores <- as.data.frame(pca_result$x)
pca_data <- data.frame(name = pokemon_names, pca_scores)

# Rename columns for clarity
colnames(pca_data) <- c("name", paste0("PC", 1:ncol(pca_scores)))

# Save PCA-transformed data
output_pca_csv <- "data_cleaning/clean_data/clean_pokemon_images_PCA.csv"
write.csv(pca_data, output_pca_csv, row.names = FALSE)

cat("PCA-transformed CSV saved to:", output_pca_csv, "\n")
cat("  Dimensions: 985 rows x", ncol(pca_data), "columns\n")
cat("  Reduction: 120,000 pixels -> 985 PCs (99.2% reduction)\n")
