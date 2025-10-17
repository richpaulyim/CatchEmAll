# CatchEmAll: Data Science of Pokemon

This is supposed to a fun little data science project BIOS 611 at UNC-CH.

## Overview

This pokedex data on many base form pokemon (e.g., excluding mega evolutions). 

This project accomplishes three things:
1. Supervised learning - Are you as strong as you look? Regression analysis will be done modeling the pokemon stats by appearance only.
2. Unsupervised learning - How are different pokemon related to each other on some lower dimensional manifold? We will use pokemon pokedex text entries, and pokemon stats to perform clustering.
3. Pokemon recommendation - What other pokemon might you like? Based on one pokemon, there will be a recommendation system to suggest new pokemon weighed by appearance, text entry descriptions, and base stats.

## Data

- **Source**: Where the data came from (e.g., "Web scraped from [website] on [date]")
- **Files**: Brief description of key data files
- **Collection**: Any important notes about how data was gathered

## Requirements

The environment used to generate results from this project can be produced by Dockerfile.
The makefile will build all results. With the variability of web scraping results, the original csvs and pngs scraped on 10/17/25 can be found in this repo under `web_scraping/{pokemon_images,scraped_data}`.


## Usage
Within the correct Docker container (after it has been built and instantiated), just run `make` in the cloned repo.

Brief explanation of what the main scripts do.

## Project Structure
```
├── web_scraping/            # web scraping scripts and dirty data
├── data_cleaning/           # final data cleaning scripts producing model ready data
├── recommender_component/   # pokemon recommender functionality scripts here
├── supervised_component/    # modeling strength by appearance scripts here
├── unsupervised_component/  # clustering pokemon features and interpretation scripts here 
└── README.md
```


## Author

Richard Paul Yim - (rpyim@unc.edu)

## License

MIT / Academic use only / etc.
