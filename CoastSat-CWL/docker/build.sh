#!/bin/bash
# Build script for CoastSat-CWL Docker image

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Image name and tag
IMAGE_NAME="coastsat-cwl"
IMAGE_TAG="${1:-latest}"

echo "========================================="
echo "Building CoastSat-CWL Docker Image"
echo "========================================="
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# Check if requirements.txt exists
if [ ! -f "requirements.txt" ]; then
    echo "Error: requirements.txt not found"
    echo "Copying from CoastSat-minimal..."
    if [ -f "../../CoastSat-minimal/requirements.txt" ]; then
        cp ../../CoastSat-minimal/requirements.txt .
        echo "✓ Copied requirements.txt"
    else
        echo "Error: Could not find requirements.txt"
        exit 1
    fi
fi

# Build the image
echo "Building Docker image..."
docker build \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -f Dockerfile \
    .

echo ""
echo "========================================="
echo "Build complete!"
echo "========================================="
echo ""
echo "To test the image:"
echo "  docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} python3 -c \"from coastsat import SDS_download; print('CoastSat imported successfully')\""
echo ""
echo "To run interactively:"
echo "  docker run -it --rm ${IMAGE_NAME}:${IMAGE_TAG} /bin/bash"
echo ""

