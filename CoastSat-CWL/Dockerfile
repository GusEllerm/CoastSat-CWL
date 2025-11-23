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

SHELL ["bash", "-lc"]

# Activate env by default
RUN echo "conda activate coastsat-cwl" >> ~/.bashrc

# Point everything at the env's data dirs
ENV CONDA_ENV=coastsat-cwl
ENV CONDA_PREFIX=/opt/conda/envs/${CONDA_ENV}
ENV PATH=${CONDA_PREFIX}/bin:$PATH
ENV PROJ_LIB=${CONDA_PREFIX}/share/proj
ENV PROJ_DATA=${CONDA_PREFIX}/share/proj
ENV GDAL_DATA=${CONDA_PREFIX}/share/gdal

# Symlinks for libs that look in /opt/conda/share/...
RUN mkdir -p /opt/conda/share && \
    ln -s ${PROJ_LIB} /opt/conda/share/proj || true && \
    ln -s ${GDAL_DATA} /opt/conda/share/gdal || true


# Copy workflow code
COPY . /workflow
WORKDIR /workflow
