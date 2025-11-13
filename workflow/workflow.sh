#!/bin/bash
# Minimal CoastSat workflow script
# This script runs the minimal version of the CoastSat workflow without git operations

set -e  # Exit on error

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================="
echo "CoastSat Minimal Workflow"
echo "========================================="
echo "Project root: $PROJECT_ROOT"
echo ""

# Step 1: Batch process NZ sites
echo "Step 1: Batch processing NZ sites..."
python3 scripts/batch_process_NZ.py
echo ""

# Step 2: Batch process SAR sites
echo "Step 2: Batch processing SAR sites..."
python3 scripts/batch_process_sar.py
echo ""

# Step 3: Run tidal correction and processing scripts
# For new sites, first we need to run tidal_correction to fetch the tides, 
# then we can run slope_estimation, then we can use the slopes to apply the tidal correction
# This is why tidal_correction is run twice
echo "Step 3: Running tidal correction (first pass) to fetch tides..."
python3 scripts/tidal_correction.py --mode fetch
echo ""

echo "Step 4: Running slope estimation..."
python3 scripts/slope_estimation.py
echo ""

echo "Step 5: Running tidal correction (second pass) to apply correction..."
python3 scripts/tidal_correction.py --mode apply
echo ""

echo "Step 6: Running linear models..."
python3 scripts/linear_models.py
echo ""

# Step 4: Make Excel files
echo "Step 7: Creating Excel files..."
python3 scripts/make_xlsx.py
echo ""

echo "========================================="
echo "Workflow completed successfully!"
echo "========================================="

