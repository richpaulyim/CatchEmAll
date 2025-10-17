library(tidyverse)
library(rvest)

destdir <- "web_scraping/scraped_data/"
dir.create(destdir, showWarnings = FALSE)
nativeDex.url <- "https://pokemondb.net/pokedex/all"
pokeTable <- read_html(nativeDex.url) %>% html_element(".data-table")

# Get all rows
rows <- pokeTable %>% html_elements("tbody tr")

# Extract data from each row
pokemon_data <- map_df(rows, function(row) {
  # Get the Pokémon number
  number <- row %>% 
    html_element(".cell-num") %>% 
    html_attr("data-sort-value")
  
  # Get the image URL from source srcset
  image_url <- row %>% 
    html_element("source") %>% 
    html_attr("srcset")
  
  # If no source, try img src
  if (is.na(image_url)) {
    image_url <- row %>% 
      html_element("img") %>% 
      html_attr("src")
  }
  
  # Get the alt text from the img tag - THIS IS THE KEY PART
  name_text <- row %>% 
    html_elements("a.ent-name") %>% html_text2()
  # Clean the alt text for use as filename
  url_name <- head(unlist(str_split(
    tail(unlist(str_split(image_url,"/"),1),1),
    ".avif")),1) 
  alt_text <- row %>% 
    html_element("img.img-fixed") %>% 
    html_attr("alt")
  
  tibble(
    number = number,
    url_name = url_name,
    name = name_text,
    alt_name = alt_text,
    image_url = image_url
  )
})

pokemon_data %>% 
  filter(name==alt_name) %>% 
  write_csv(paste0(destdir,"pokemon_metadata.csv"))
