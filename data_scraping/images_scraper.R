library(rvest)
library(tidyverse)
library(magick)

# read pokemon data in 
pokemon_data <- read_csv("data_scraping/scraped_data/pokemon_metadata.csv")

# Download function using alt text as filename
download_with_alt_names <- function(data, dest_folder = "data_scraping/pokemon_images") {
  dir.create(dest_folder, showWarnings = FALSE)
  n <- nrow(data)
  failed_count <- 0
  skipped_count <- 0

  for (i in 1:nrow(data)) {
    img_url <- data$image_url[i]
    url_name <- data$url_name[i]

    if (!is.na(img_url) && !is.na(url_name)) {

      # Create filename using alt text
      filename <- paste0(url_name, ".png")
      filepath <- file.path(dest_folder, filename)

      # Skip if file already exists
      if (file.exists(filepath)) {
        skipped_count <- skipped_count + 1
        if (i %% 50 == 0) cat("Processed", i, "of", n, "entries (", skipped_count, "skipped )\n")
        next
      }

      tryCatch({
        # Read and convert to PNG
        img <- image_read(img_url)
        image_write(img, filepath, format = "png")

        Sys.sleep(0.01)
      }, error = function(e) {
        # Only report as failed if file doesn't exist after attempt
        if (!file.exists(filepath)) {
          cat("Failed:", url_name, "-", e$message, "\n")
          failed_count <<- failed_count + 1
        }
      })

      if (i %% 50 == 0) cat("Processed", i, "of", n, "entries\n")
    }
  }

  cat("\n=== Download Summary ===\n")
  cat("Total entries:", n, "\n")
  cat("Skipped (already exist):", skipped_count, "\n")
  cat("Failed:", failed_count, "\n")
  cat("Done!\n")
}

# Use it
download_with_alt_names(pokemon_data)
