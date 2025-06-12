FROM r-base:4.3.1

RUN apt-get update -qq && apt-get install -y \
  libssl-dev \
  libcurl4-gnutls-dev

RUN apt-get install -y software-properties-common gnupg libssl-dev libxml2-dev libcurl4-openssl-dev build-essential libgit2-dev zlib1g-dev liblapack-dev libblas-dev

RUN apt-get update && apt-get install -y libsodium-dev

RUN R -e "install.packages('sodium')"
RUN R -e "install.packages('dotenv')"
RUN R -e "install.packages('aws.s3')"
RUN R -e "install.packages('aws.ec2metadata', dependencies=TRUE)"
RUN R -e "install.packages('plumber')"

RUN R -e "install.packages('curl')"
RUN R -e "install.packages('httr')"
RUN R -e "install.packages(c('xml2', 'biomaRt'), dependencies=TRUE)"


RUN R -e "install.packages('BiocManager', dependencies=TRUE)"
RUN R -e "BiocManager::install('GenomicRanges')"
RUN R -e "BiocManager::install('trackViewer')"
RUN R -e "BiocManager::install('Gviz')"
RUN R -e "BiocManager::install('limma')"



COPY . /app

ENTRYPOINT ["Rscript", "/app/run_api.R"]

