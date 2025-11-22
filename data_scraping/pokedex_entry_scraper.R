library(rvest)
library(tidyverse)

# metadata read
metadata <- read_csv("data_scraping/scraped_data/pokemon_metadata.csv")

pokemon_entries <- map_df(1:nrow(metadata), function(i) {
  poke_name <- metadata$url_name[i]
  
  tryCatch({
    url <- paste0("https://pokemondb.net/pokedex/", poke_name)
    entry_text <- read_html(url) %>% 
      html_elements("td.cell-med-text") %>% 
      html_text2() %>%
      paste(collapse = " ")
    
    if (i %% 50 == 0) cat("Downloaded", i, "of", n, "entries\n")
    Sys.sleep(0.01)
    
    tibble(name = poke_name, entry_text = entry_text)
  }, error = function(e) {
    cat("Failed to scrape:", poke_name, "\n")
    tibble(name = poke_name, entry_text = NA_character_)
  })
})

pokemon_entries %>% write_csv("data_scraping/scraped_data/pokedex_entries.csv")
