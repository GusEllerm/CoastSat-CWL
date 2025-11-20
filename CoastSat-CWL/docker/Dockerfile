# Docker image for CoastSat CWL tools
# This image contains all dependencies needed to run the CoastSat CWL workflow tools

FROM python:3.11-slim

# Set working directory
WORKDIR /tools

# Install system dependencies required for geospatial libraries
# Note: Qt/PyQt5 dependencies removed since we don't use interactive GUI features
RUN apt-get update && apt-get install -y \
    gdal-bin \
    libgdal-dev \
    python3-gdal \
    g++ \
    gcc \
    make \
    libproj-dev \
    proj-data \
    proj-bin \
    libgeos-dev \
    libspatialindex-dev \
    && rm -rf /var/lib/apt/lists/*

# Set GDAL environment variables
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal

# Copy requirements file
COPY docker/requirements.txt /tmp/requirements.txt

# Install Python dependencies
# Note: PyQt5 is only needed for interactive GUI features (check_detection/adjust_detection),
# which are disabled in our CWL tools (both set to False). We install coastsat_package
# with --no-deps to skip PyQt5, then manually install its other dependencies.
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
        geopandas>=0.14.0 \
        shapely>=2.0.0 \
        "numpy<2.0.0" \
        "pandas>=2.0.0" \
        "scipy>=1.10.0" \
        "earthengine-api>=0.1.350" \
        "tqdm>=4.65.0" \
        "matplotlib>=3.7.0" \
        "python-dotenv>=1.0.0" && \
    pip install --no-cache-dir coastsat_package --no-deps && \
    pip install --no-cache-dir scikit-image scikit-learn jupyterlab astropy importlib-resources

# Copy tool scripts into the image
COPY tools/list_nz_sites/list_nz_sites.py /tools/list_nz_sites/list_nz_sites.py

# Set default command
CMD ["/bin/bash"]

