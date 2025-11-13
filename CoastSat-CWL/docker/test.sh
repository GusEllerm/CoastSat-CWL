#!/bin/bash
# Test script for CoastSat-CWL Docker image

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Image name and tag
IMAGE_NAME="coastsat-cwl"
IMAGE_TAG="${1:-latest}"

echo "========================================="
echo "Testing CoastSat-CWL Docker Image"
echo "========================================="
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# Test 1: Python version
echo "Test 1: Python version"
docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" python3 --version
echo "✓ Python version check passed"
echo ""

# Test 2: GDAL version
echo "Test 2: GDAL installation"
docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" python3 -c "from osgeo import gdal; print(f'GDAL version: {gdal.__version__}')"
echo "✓ GDAL import check passed"
echo ""

# Test 3: GeoPandas import
echo "Test 3: GeoPandas import"
docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" python3 -c "import geopandas; print(f'GeoPandas version: {geopandas.__version__}')"
echo "✓ GeoPandas import check passed"
echo ""

# Test 4: CoastSat import
echo "Test 4: CoastSat import"
docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" python3 -c "from coastsat import SDS_download, SDS_preprocess, SDS_shoreline, SDS_tools, SDS_transects; print('CoastSat imported successfully')"
echo "✓ CoastSat import check passed"
echo ""

# Test 5: Other key dependencies
echo "Test 5: Other dependencies"
docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" python3 -c "import pandas; import numpy; import scipy; import matplotlib; import earthengine as ee; print('All dependencies imported successfully')"
echo "✓ Dependencies check passed"
echo ""

echo "========================================="
echo "All tests passed!"
echo "========================================="

