# CoastSat-CWL Base Docker Image
# This image contains all dependencies required for the CoastSat CWL workflow

FROM python:3.11-slim

# Set maintainer
LABEL maintainer="CoastSat-CWL Team"
LABEL description="Base image for CoastSat CWL workflow with all dependencies"
LABEL version="1.0"

# Set working directory
WORKDIR /app

# Install system dependencies required for geospatial processing
# GDAL and its dependencies, plus Qt for PyQt5 (required by coastsat_package)
RUN apt-get update && apt-get install -y \
    gdal-bin \
    libgdal-dev \
    python3-gdal \
    proj-bin \
    libproj-dev \
    libgeos-dev \
    libspatialindex-dev \
    build-essential \
    pkg-config \
    qtbase5-dev \
    qttools5-dev-tools \
    qt5-qmake \
    && rm -rf /var/lib/apt/lists/*

# Set GDAL environment variables
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal

# Copy requirements file
COPY requirements.txt /tmp/requirements.txt

# Install Python dependencies (without GDAL - will install separately to match system version)
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Get GDAL version and install matching Python bindings first
RUN GDAL_VERSION=$(gdal-config --version | cut -d. -f1,2) && \
    echo "Installing GDAL Python bindings for version ${GDAL_VERSION}" && \
    pip install --no-cache-dir gdal==${GDAL_VERSION}.*

# Install other Python dependencies
# Split installation to reduce memory pressure during PyQt5 build
# First install most dependencies (without coastsat_package which pulls in PyQt5)
RUN pip install --no-cache-dir \
    geopandas \
    scipy \
    matplotlib \
    matplotlib_venn \
    "numpy<2" \
    python-dotenv \
    openpyxl \
    pandas \
    requests \
    tqdm \
    earthengine-api \
    scikit-learn \
    astropy \
    pytz \
    scikit-image

# Install coastsat_package without Jupyter/PyQt5 if possible
# PyQt5 is only needed for Jupyter notebooks, not for command-line execution
# Try installing without PyQt5 first, fall back to full install if needed
RUN pip install --no-cache-dir --no-deps coastsat_package || \
    (echo "Attempting to install coastsat_package with PyQt5 (may take 15-30 minutes)..." && \
     MAKEFLAGS=-j1 pip install --no-cache-dir coastsat_package)

# Note: If PyQt5 installation fails due to memory issues, you can:
# 1. Increase Docker Desktop memory to 8GB
# 2. Or install PyQt5 from pre-built wheels if available for your architecture

# Verify installations
RUN python3 -c "from osgeo import gdal; print(f'GDAL version: {gdal.__version__}')" && \
    python3 -c "import geopandas; print('GeoPandas imported successfully')" && \
    python3 -c "from coastsat import SDS_download; print('CoastSat imported successfully')" && \
    echo "All imports verified successfully"

# Set Python path
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Default command (can be overridden in CWL tools)
CMD ["python3", "--version"]

