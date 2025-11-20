# Dockerfile for CoastSat Validation Workflow
# Based on Ubuntu to match the original production environment

FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies (including GDAL for geopandas and Qt for PyQt5)
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    git \
    wget \
    curl \
    libgdal-dev \
    gdal-bin \
    python3-gdal \
    libgeos-dev \
    libproj-dev \
    qtbase5-dev \
    pyqt5-dev \
    python3-pyqt5 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY workflow/requirements.txt /app/requirements.txt

# Upgrade pip and install build tools
RUN pip3 install --upgrade pip setuptools wheel

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt || \
    (echo "Installation failed, trying with verbose output..." && \
     pip3 install --no-cache-dir -v -r requirements.txt)

# Install Jupyter for notebook execution
RUN pip3 install --no-cache-dir jupyter nbconvert ipython-autotime papermill

# Copy workflow files
COPY workflow/ /app/

# Create data directory
RUN mkdir -p /app/data

# Set Python path
ENV PYTHONPATH=/app:$PYTHONPATH

# Default command
CMD ["/bin/bash"]

