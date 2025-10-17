# directories
WEB_DIR = web_scraping
DATA_DIR = web_scraping
IMAGE_DIR = $(WEB_DIR)/pokemon_images
DIRTY_DATA_DIR = $(WEB_DIR)/scraped_data
# scripts names
METADATA_SCRIPT = $(WEB_DIR)/meta_table_scraper.R
IMAGE_SCRIPT = $(WEB_DIR)/images_scraper.R
STATS_TABLE_SCRIPT = $(WEB_DIR)/pokemon_stats_table.R
POKEDEX_ENTRY_SCRIPT = $(WEB_DIR)/pokedex_entry_scraper.R
# files
METADATA_CSV = $(DIRTY_DATA_DIR)/pokemon_metadata.csv
POKE_STATS_CSV = $(DIRTY_DATA_DIR)/pokemon_stats.csv
POKE_ENTRIES_CSV = $(DIRTY_DATA_DIR)/pokedex_entries.csv

# Default: run everything
all: metadata pokeimages pokeentries pokestats
# Individual targets
metadata: $(METADATA_CSV)
pokeimages: $(IMAGE_DIR)/.timestamp
pokeentries: $(POKE_ENTRIES_CSV)
pokestats: $(POKE_STATS_CSV)

# Step 1: Scrape metadata (creates CSV with URLs, names, etc.)
$(METADATA_CSV): $(METADATA_SCRIPT)
	@echo "Scraping Pokemon metadata..."
	Rscript $(METADATA_SCRIPT)

# Step 2: Download images (depends on metadata)
$(IMAGE_DIR)/.timestamp: $(IMAGE_SCRIPT) $(METADATA_CSV)
	@echo "Downloading Pokemon images..."
	Rscript $(IMAGE_SCRIPT)
	@touch $(IMAGE_DIR)/.timestamp

# Step 3: download pokedex entries (depends on metadata)
$(POKE_ENTRIES_CSV): $(POKEDEX_ENTRY_SCRIPT) $(METADATA_CSV)
	@echo "Downloading Pokedex entries..."
	Rscript $(POKEDEX_ENTRY_SCRIPT)

# Step 4: download vitals table (depends on metadata)
$(POKE_STATS_CSV): $(VITAL_TABLE_SCRIPT) $(METADATA_CSV)
	@echo "Downloading Pokemon stats data..."
	Rscript $(STATS_TABLE_SCRIPT)

# Clean targets
clean-metadata:	
	rm -rf $(METADATA_CSV)
clean-pokeimages:
	rm -rf $(IMAGE_DIR)
clean-pokeentries:
	rm -rf $(POKE_ENTRIES_CSV)
clean-pokestats:
	rm -rf $(POKE_STATS_CSV)
clean: clean-metadata clean-pokeimages clean-pokestats clean-pokeentries

# Rebuild everything
rebuild: clean all

.PHONY: all metadata pokeimages pokestats pokeentries\
	clean clean-metadata clean-pokeimages clean-pokestats\
	clean-pokeentries rebuild