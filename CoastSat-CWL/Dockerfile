FROM continuumio/miniconda3:latest

# Basic OS updates (optional but fine)
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workflow

# Copy env spec
COPY environment.yml /workflow/environment.yml

# Configure channels and create the env
RUN conda config --system --add channels conda-forge && \
    conda config --system --add channels fbriol && \
    conda config --system --add channels defaults && \
    conda config --system --set channel_priority strict && \
    conda env create -f /workflow/environment.yml && \
    conda clean -a -y

# Make that env the default shell env
SHELL ["bash", "-lc"]
RUN echo "conda activate coastsat-cwl" >> ~/.bashrc

# Ensure PATH / PROJ are correct
ENV PATH=/opt/conda/envs/coastsat-cwl/bin:$PATH
ENV PROJ_LIB=/opt/conda/envs/coastsat-cwl/share/proj

# Copy workflow code
COPY . /workflow
WORKDIR /workflow
