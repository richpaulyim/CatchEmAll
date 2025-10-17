library(rvest)
library(tidyverse)
library(magick)

# read pokemon data in 
pokemon_data <- read_csv("web_scraping/scraped_data/pokemon_metadata.csv")

# Download function using alt text as filename
download_with_alt_names <- function(data, dest_folder = "web_scraping/pokemon_images") {
  dir.create(dest_folder, showWarnings = FALSE)
  n <- nrow(data)
  for (i in 1:nrow(data)) {
    img_url <- data$image_url[i]
    url_name <- data$url_name[i]
    
    if (!is.na(img_url) && !is.na(url_name)) {
      
      # Create filename using alt text
      filename <- paste0(url_name, ".png")
      filepath <- file.path(dest_folder, filename)
      
      tryCatch({
        # Read and convert to PNG
        img <- image_read(img_url)
        image_write(img, filepath, format = "png")
        
        if (i %% 50 == 0) cat("Downloaded", i, "of", n, "entries\n")
        
        Sys.sleep(0.01)
      }, error = function(e) {
        cat("Failed:", url_name, "\n")
      })
    }
  }
  cat("Done!\n")
}

# Use it
download_with_alt_names(pokemon_data)
