FROM rocker/r-ver:4.3.1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libgit2-dev \
    libsodium-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libpng-dev \
    libfreetype6-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libtiff5-dev \
    libjpeg-dev \
    liblapack-dev \
    libblas-dev \
    software-properties-common \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install CRAN packages
RUN R -e "install.packages(c('BiocManager','sodium','dotenv','aws.s3','aws.ec2metadata','plumber','curl','httr','xml2'), repos='https://cloud.r-project.org')"

# Install Bioconductor packages
RUN R -e "BiocManager::install(version='3.18', ask=FALSE)"

RUN R -e "BiocManager::install(c('S4Vectors','IRanges','GenomeInfoDb','GenomicRanges'), ask=FALSE, update=FALSE)"

RUN R -e "BiocManager::install(c('trackViewer','Gviz','limma','biomaRt'), ask=FALSE, update=FALSE)"

# Copy project
COPY . /app
WORKDIR /app

EXPOSE 8000

ENTRYPOINT ["Rscript", "run_api.R"]