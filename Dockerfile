FROM rocker/verse:latest

# Install Emacs and ESS
RUN apt-get update && apt-get install -y \
    texlive-latex-extra \ 
    texlive-fonts-recommended \
    emacs \
    elpa-ess \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('survival', 'caret', 'magick', 'tidytext', 'tidyverse'), repos='https://cloud.r-project.org/')"

# Copy Emacs config
COPY .emacs /home/rstudio/.emacs

WORKDIR /home/rstudio

CMD ["/init"]
