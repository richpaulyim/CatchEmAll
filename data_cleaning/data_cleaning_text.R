library(tidyverse)
library(tidytext)
library(stringr)

# read in metadata and dirty data
metadata <- read_csv("data_scraping/scraped_data/pokemon_metadata.csv")
text_data <- read_csv("data_scraping/scraped_data/pokedex_entries.csv") %>% 
  rename(url_name=name) %>% 
  left_join(
    metadata %>% select(name,url_name), 
    by = "url_name" 
    ) %>% select(-url_name)

text_cleaned <- text_data %>%
  mutate(
    # Keep only letters (a-z, A-Z), replace everything else with space
    text_clean = str_replace_all(entry_text, "[^a-zA-Z]", " "),
    # Trim edges and replace repeated whitespace with single space
    text_clean = str_trim(text_clean),
    text_clean = str_replace_all(text_clean, "\\s+", " "),
    # Break into array of words
    words = str_split(tolower(text_clean), " ")
  ) %>% 
  select(name,words) %>% 
  unnest(words)

# modeling ready text data without stop words
tidy_dist <- text_cleaned %>% 
  anti_join(stop_words, by = c("words" = "word")) %>% 
  count(name, words) %>% 
  pivot_wider(
    names_from = words,
    values_from = n,
    values_fill = 0
  )

# create output directory
destdir <- "data_cleaning/clean_data/"
dir.create(destdir, showWarnings = FALSE)

# ============================================================================
# SVD Analysis: Create SVD-reduced representation
# ============================================================================

# Prepare the data matrix (exclude the name column)
text_matrix <- tidy_dist %>%
  select(-name) %>%
  as.matrix()

# Add row names for reference
rownames(text_matrix) <- tidy_dist$name

cat(sprintf("Matrix dimensions: %d x %d\n", nrow(text_matrix), ncol(text_matrix)))

# Perform SVD
cat("Performing SVD decomposition...\n")
svd_result <- svd(text_matrix)

# Use maximum number of components (min of rows and columns)
n_components <- min(nrow(text_matrix), ncol(text_matrix))

cat(sprintf("Creating SVD-reduced representation with %d components (maximum)...\n", n_components))

# Get the SVD-transformed features: U * D (scores matrix)
# This is the Pokemon x Components matrix
U_reduced <- svd_result$u[, 1:n_components, drop = FALSE]
D_reduced <- svd_result$d[1:n_components]

# Create the transformed data (U * D)
svd_features <- U_reduced %*% diag(D_reduced, nrow = length(D_reduced))

# Add Pokemon names and convert to data frame
svd_df <- as.data.frame(svd_features)
colnames(svd_df) <- paste0("SVD_", 1:n_components)
svd_df <- tibble(name = tidy_dist$name) %>%
  bind_cols(svd_df)

# Write out the SVD-reduced data
svd_df %>% write_csv("data_cleaning/clean_data/clean_pokemon_text_SVD.csv")

cat(sprintf("SVD-reduced data saved to: data_cleaning/clean_data/clean_pokemon_text_SVD.csv\n"))
cat(sprintf("Output dimensions: %d Pokemon x %d SVD components\n", nrow(svd_df), n_components))
