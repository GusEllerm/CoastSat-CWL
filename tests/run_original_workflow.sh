#!/bin/bash
# Script to run the original CoastSat workflow for validation
# This script runs the original workflow without git operations

set -e  # Exit on error

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================="
echo "Running Original CoastSat Workflow"
echo "========================================="
echo "Project root: $PROJECT_ROOT"
echo ""

# Check if CoastSat directory exists
if [ ! -d "CoastSat" ]; then
    echo "❌ Error: CoastSat directory not found"
    echo "Please ensure the original CoastSat codebase is in the CoastSat/ directory"
    exit 1
fi

# Change to CoastSat directory
cd CoastSat

# Check if input files exist
if [ ! -f "polygons.geojson" ] || [ ! -f "shorelines.geojson" ] || [ ! -f "transects_extended.geojson" ]; then
    echo "⚠️  Warning: Input files not found in CoastSat directory"
    echo "Copying filtered inputs from inputs/ directory..."
    cp ../inputs/polygons.geojson .
    cp ../inputs/shorelines.geojson .
    cp ../inputs/transects_extended.geojson .
fi

# Step 1: Batch process NZ sites
echo "Step 1: Batch processing NZ sites..."
python3 batch_process_NZ.py
echo ""

# Step 2: Batch process SAR sites
echo "Step 2: Batch processing SAR sites..."
python3 batch_process_sar.py
echo ""

# Step 3: Run notebooks
# For new sites, first we need to run tidal_correction to fetch the tides, 
# then we can run slope_estimation, then we can use the slopes to apply the tidal correction
# This is why tidal_correction.ipynb is run twice
echo "Step 3: Running tidal correction (first pass) to fetch tides..."
jupyter nbconvert --to notebook --execute --inplace tidal_correction.ipynb
echo ""

echo "Step 4: Running slope estimation..."
jupyter nbconvert --to notebook --execute --inplace slope_estimation.ipynb
echo ""

echo "Step 5: Running tidal correction (second pass) to apply correction..."
jupyter nbconvert --to notebook --execute --inplace tidal_correction.ipynb
echo ""

echo "Step 6: Running linear models..."
jupyter nbconvert --to notebook --execute --inplace linear_models.ipynb
echo ""

# Step 7: Make Excel files
echo "Step 7: Creating Excel files..."
python3 make_xlsx.py
echo ""

echo "========================================="
echo "Original workflow completed successfully!"
echo "========================================="
echo ""
echo "Output files are in: CoastSat/data/"
echo "You can now run the comparison script:"
echo "  python3 tests/compare_with_original.py"

