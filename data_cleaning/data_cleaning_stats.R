library(tidyverse)
library(magick)
library(purrr)
library(stringr)

# read in metadata and dirty data
metadata <- read_csv("web_scraping/scraped_data/pokemon_metadata.csv")
dirty_data <- read_csv("web_scraping/scraped_data/pokemon_stats.csv") %>% 
  rename(url_name=pokedex_names) %>% 
  left_join(
    metadata %>% select(name,url_name), 
    by = "url_name"
    )

# cleaning elementType
data_elType <- dirty_data %>% 
  mutate(
    elementType=str_split(elementType, "\t")
  ) %>%
  unnest(elementType) %>% 
  filter(elementType!= "") %>%
  mutate(elementType=paste0("pType_",elementType)) %>% 
  mutate(value = 1) %>%
  pivot_wider(
    names_from = elementType,
    values_from = value,
    values_fill = 0
  ) 

# cleaning species 
data_species <- data_elType %>% 
  mutate(species = paste0("species_",
                          str_remove(species," Pokémon"))
         ) %>% 
  filter(species!= "") %>%
  mutate(value = 1) %>%
  pivot_wider(
    names_from = species,
    values_from = value,
    values_fill = 0
  ) 

# height and weight
data_hw <- data_species %>% 
  mutate(
    height_m = as.numeric(str_extract(height, "^[0-9.]+")),
    weight_kg = as.numeric(str_extract(weight, "^[0-9.]+"))
    ) %>% 
  select(-c(height, weight))

# egg groups
data_eggGroup <- data_hw %>% 
  mutate(
    eggGroups=str_split(eggGroups, ", ")
  ) %>%
    unnest(eggGroups) %>% 
    filter(eggGroups!= "") %>%
    mutate(eggGroups=paste0("eggGroup_",
                              str_trim(eggGroups))
           ) %>% 
    mutate(value = 1) %>%
    pivot_wider(
      names_from = eggGroups,
      values_from = value,
      values_fill = 0
    ) 
  
# egg cycle 
data_eggCycle <- data_eggGroup %>% 
  mutate(
    eggCycle=str_split(eggCycle, "\t")
  ) %>% 
  unnest(eggCycle) %>% 
  group_by(name) %>% slice(1) %>% ungroup() %>% 
  mutate(
    eggCycle=as.numeric(eggCycle),
    eggCycle=replace_na(as.numeric(eggCycle), mean(eggCycle, na.rm = TRUE))
  )

# gender column
data_gender <- data_eggCycle %>%
  mutate(
    male = case_when(
      gender == "Genderless" ~ 0,
      TRUE ~ as.numeric(str_extract(gender, "^[0-9.]+"))
    ),
    female = case_when(
      gender == "Genderless" ~ 0,
      TRUE ~ as.numeric(str_extract(gender, "[0-9.]+(?=% female)"))
    )
  ) %>% select(-c(gender,url_name))
  
# check that fully numeric
tibble(
  column = names(data_gender),
  type = sapply(data_gender, class)
) %>% count(type) %>% print(n=10000)

# impute any remaining NAs with 0
cat("\nChecking for missing values before writing...\n")
n_missing <- sum(is.na(data_gender))
cat(sprintf("  Total missing values: %d\n", n_missing))

if(n_missing > 0) {
  cat("  Imputing missing values with 0...\n")
  data_gender <- data_gender %>%
    mutate(across(everything(), ~replace_na(., 0)))
  cat(sprintf("  After imputation: %d missing values\n", sum(is.na(data_gender))))
}

# write out csv
destdir <- "data_cleaning/clean_data/"
dir.create(destdir, showWarnings = FALSE)
data_gender %>% write_csv("data_cleaning/clean_data/clean_pokemon_stats.csv")
