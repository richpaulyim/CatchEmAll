FROM rocker/verse:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    texlive-latex-extra \
    texlive-fonts-recommended \
    emacs \
    elpa-ess \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Install Python and pip (separate layer to preserve R package cache)
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --break-system-packages --no-cache-dir \
    numpy \
    pandas \
    scipy \
    matplotlib \
    seaborn \
    scikit-learn \
    jupyter

# Install R packages (only those actually used in the project)
RUN R -e "install.packages( \
    c( \
        'tidyverse',  \
        'corpcor',  \
        'cluster',  \
        'plotly',  \
        'magick',  \
        'tidytext',  \
        'Rtsne',  \
        'xgboost',  \
        'rvest'),  \
    repos='https://cloud.r-project.org/')"

WORKDIR /home/rstudio

CMD ["/init"]
