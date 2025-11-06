# directories
WEB_DIR = web_scraping
DATA_DIR = data_cleaning
IMAGE_DIR = $(WEB_DIR)/pokemon_images
DIRTY_DATA_DIR = $(WEB_DIR)/scraped_data
CLEAN_DATA_DIR = $(DATA_DIR)/clean_data
# scripts names
METADATA_SCRIPT = $(WEB_DIR)/meta_table_scraper.R
IMAGE_SCRIPT = $(WEB_DIR)/images_scraper.R
STATS_TABLE_SCRIPT = $(WEB_DIR)/pokemon_stats_table.R
POKEDEX_ENTRY_SCRIPT = $(WEB_DIR)/pokedex_entry_scraper.R
STAT_CLEAN_SCRIPT = $(DATA_DIR)/data_cleaning_stats.R
TEXT_CLEAN_SCRIPT = $(DATA_DIR)/data_cleaning_text.R
IMAGE_CLEAN_SCRIPT = $(DATA_DIR)/data_cleaning_images.R
# files
METADATA_CSV = $(DIRTY_DATA_DIR)/pokemon_metadata.csv
POKE_STATS_CSV = $(DIRTY_DATA_DIR)/pokemon_stats.csv
POKE_ENTRIES_CSV = $(DIRTY_DATA_DIR)/pokedex_entries.csv
CLEAN_TEXT_CSV = $(CLEAN_DATA_DIR)/clean_pokemon_text_SVD.csv
CLEAN_STAT_CSV = $(CLEAN_DATA_DIR)/clean_pokemon_stats.csv
CLEAN_IMAGE_CSV = $(CLEAN_DATA_DIR)/clean_pokemon_images_PCA.csv

# Default: run everything
all: metadata pokeimages pokeentries pokestats\
  pokestatsclean poketextclean pokeimageclean

# Individual targets
metadata: $(METADATA_CSV)
pokeimages: $(IMAGE_DIR)/.timestamp
pokeentries: $(POKE_ENTRIES_CSV)
pokestats: $(POKE_STATS_CSV)
pokestatsclean: $(CLEAN_STAT_CSV)
poketextclean: $(CLEAN_TEXT_CSV)
pokeimageclean: $(CLEAN_IMAGE_CSV)

# Step 1: Scrape metadata (creates CSV with URLs, names, etc.)
$(METADATA_CSV): $(METADATA_SCRIPT)
	@echo "Scraping Pokemon metadata..."
	Rscript $(METADATA_SCRIPT)

# Step 2: Download images (depends on metadata)
$(IMAGE_DIR)/.timestamp: $(IMAGE_SCRIPT) $(METADATA_CSV)
	@echo "Downloading Pokemon images..."
	Rscript $(IMAGE_SCRIPT)
	@touch $(IMAGE_DIR)/.timestamp

# Step 3: Download Pokedex entries (depends on metadata)
$(POKE_ENTRIES_CSV): $(POKEDEX_ENTRY_SCRIPT) $(METADATA_CSV)
	@echo "Downloading Pokedex entries..."
	Rscript $(POKEDEX_ENTRY_SCRIPT)

# Step 4: Download Pokemon stats (depends on metadata)
$(POKE_STATS_CSV): $(STATS_TABLE_SCRIPT) $(METADATA_CSV)
	@echo "Downloading Pokemon stats data..."
	Rscript $(STATS_TABLE_SCRIPT)

# Step 5: Clean stats data
$(CLEAN_STAT_CSV): $(STAT_CLEAN_SCRIPT) $(METADATA_CSV) $(POKE_STATS_CSV)
	@echo "Cleaning Pokemon stats data..."
	Rscript $(STAT_CLEAN_SCRIPT)

# Step 6: Clean text data and create SVD-transformed CSV
$(CLEAN_TEXT_CSV): $(TEXT_CLEAN_SCRIPT) $(METADATA_CSV) $(POKE_ENTRIES_CSV)
	@echo "Cleaning Pokemon text data and creating SVD representation..."
	Rscript $(TEXT_CLEAN_SCRIPT)

# Step 7: Clean image data and create PCA-transformed CSV
$(CLEAN_IMAGE_CSV): $(IMAGE_CLEAN_SCRIPT) $(IMAGE_DIR)/.timestamp
	@echo "Processing Pokemon images and creating PCA representation..."
	Rscript $(IMAGE_CLEAN_SCRIPT)

# Clean targets
clean-metadata:
	rm -rf $(METADATA_CSV)
clean-pokeimages:
	rm -rf $(IMAGE_DIR)
clean-pokeentries:
	rm -rf $(POKE_ENTRIES_CSV)
clean-pokestats:
	rm -rf $(POKE_STATS_CSV)
clean-poketextclean:
	rm -rf $(CLEAN_TEXT_CSV)
clean-pokestatclean:
	rm -rf $(CLEAN_STAT_CSV)
clean-pokeimageclean:
	rm -rf $(CLEAN_IMAGE_CSV)
clean: clean-metadata clean-pokeimages clean-pokestats clean-pokeentries\
  clean-pokestatclean clean-poketextclean clean-pokeimageclean

# Rebuild everything
rebuild: clean all

.PHONY: all metadata pokeimages pokestats pokeentries\
  pokestatsclean poketextclean pokeimageclean\
  clean clean-metadata clean-pokeimages clean-pokestats clean-pokeentries\
  clean-pokestatclean clean-poketextclean clean-pokeimageclean rebuild