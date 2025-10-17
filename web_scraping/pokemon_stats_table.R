library(rvest)
library(tidyverse)

conv_char_num <- function(x) {
  case_when(
    x == "½" ~ 0.5,
    x == "¼" ~ 0.25,
    x == "0" ~ 0,
    x == "1" ~ 1,
    x == "2" ~ 2,
    x == "4" ~ 4,
    is.na(x) ~ 1
  )
}

# metadata read
metadata <- read_csv("web_scraping/scraped_data/pokemon_metadata.csv")
n <- nrow(metadata)  # or however many you want to scrape

# Initialize tibble
pokedex_stats <- tibble(
  pokedex_names = character(n),
  elementType = character(n),
  species = character(n),
  height = character(n),
  weight = character(n),
  gender = character(n),
  eggGroups = character(n),
  eggCycle = character(n),
  # Base stats
  base_hp = numeric(n),
  base_attack = numeric(n),
  base_defense = numeric(n),
  base_spAtk = numeric(n),
  base_spDef = numeric(n),
  base_speed = numeric(n),
  # Min lvl 100
  min100_hp = numeric(n),
  min100_attack = numeric(n),
  min100_defense = numeric(n),
  min100_spAtk = numeric(n),
  min100_spDef = numeric(n),
  min100_speed = numeric(n),
  # Max lvl 100
  max100_hp = numeric(n),
  max100_attack = numeric(n),
  max100_defense = numeric(n),
  max100_spAtk = numeric(n),
  max100_spDef = numeric(n),
  max100_speed = numeric(n),
  # element types
  type_normal = numeric(n),
  type_fire = numeric(n),
  type_water = numeric(n),
  type_electricity = numeric(n),
  type_grass = numeric(n),
  type_ice = numeric(n),
  type_fighting = numeric(n),
  type_poison = numeric(n),
  type_ground = numeric(n),
  type_flying = numeric(n),
  type_psychic = numeric(n),
  type_bug = numeric(n),
  type_rock = numeric(n),
  type_ghost = numeric(n),
  type_dragon = numeric(n),
  type_dark = numeric(n),
  type_steel = numeric(n),
  type_fairy = numeric(n)
)

# Scraping loop
for (i in 1:n) {  # Change to 1:n for all Pokemon
  poke_name <- metadata$url_name[i]
  
  tryCatch({
    url <- paste0("https://pokemondb.net/pokedex/", poke_name)
    
    # read in tables 
    tvitals <- read_html(url) %>% 
      html_elements(".vitals-table") %>% 
      html_table()
    ttype <- read_html(url) %>% 
      html_elements(".type-table") %>% 
      html_table()
    
    # table 1 - basic info
    pokedex_stats$pokedex_names[i] <- poke_name
    pokedex_stats$elementType[i] <- tvitals[[1]]$X2[2]
    pokedex_stats$species[i] <- tvitals[[1]]$X2[3]
    pokedex_stats$height[i] <- tvitals[[1]]$X2[4]
    pokedex_stats$weight[i] <- tvitals[[1]]$X2[5]
    
    # table 3 - breeding info
    pokedex_stats$eggGroups[i] <- tvitals[[3]]$X2[1]
    pokedex_stats$gender[i] <- tvitals[[3]]$X2[2]
    pokedex_stats$eggCycle[i] <- tvitals[[3]]$X2[3]
    
    # table 4 - combat stats (base, min, max)
    combat_stats <- as.list(as.numeric(c(
      tvitals[[4]]$X2[1:6],   # base stats
      tvitals[[4]]$X4[1:6],   # min lvl 100
      tvitals[[4]]$X5[1:6]    # max lvl 100
    )))
    pokedex_stats[i, 9:26] <- combat_stats
    
    # defense types - type effectiveness table
    type_effectiveness <- as.list(sapply(unlist(ttype), conv_char_num)[1:18])
    pokedex_stats[i, 27:44] <- type_effectiveness
    
    if (i %% 50 == 0) cat("Downloaded", i, "of", n, "entries\n")
    Sys.sleep(0.01)
    
  }, error = function(e) {
    cat("Failed to scrape:", poke_name, "at index", i, "\n")
    cat("Error message:", e$message, "\n")
  })
}

# Save results
pokedex_stats %>% write_csv("web_scraping/scraped_data/pokemon_stats.csv")
