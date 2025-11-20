#!/bin/bash
# Prepare workflow directory for validation execution
# This script:
# 1. Copies baseline data to workflow directory
# 2. Filters polygons.geojson and shorelines.geojson to only include validation sites
# 3. Creates a validation-specific update script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_DIR="$SCRIPT_DIR"
BASELINE_DIR="$VALIDATION_DIR/baseline"
WORKFLOW_DIR="$VALIDATION_DIR/workflow"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Preparing Workflow for Validation${NC}"
echo "======================================"

# Check if baseline data exists
if [ ! -f "$BASELINE_DIR/transects_extended.geojson" ]; then
    echo -e "${RED}Error: Baseline data not found. Run setup_validation.sh first.${NC}"
    exit 1
fi

# Step 0: Clean up workflow directory (remove old data)
echo -e "\n${YELLOW}Step 0: Cleaning workflow directory...${NC}"
if [ -d "$WORKFLOW_DIR" ]; then
    # Remove data directory if it exists
    if [ -d "$WORKFLOW_DIR/data" ]; then
        echo "  - Removing old data directory..."
        rm -rf "$WORKFLOW_DIR/data"
    fi
    
    # Remove specific files that will be regenerated
    for file in "transects_extended.geojson" "polygons.geojson" "shorelines.geojson" "MAX_DATE.txt" "update_validation.sh" "check_requirements.sh"; do
        if [ -f "$WORKFLOW_DIR/$file" ]; then
            rm -f "$WORKFLOW_DIR/$file"
        fi
    done
    
    echo "  ✓ Workflow directory cleaned"
else
    # Create workflow directory if it doesn't exist
    mkdir -p "$WORKFLOW_DIR"
    echo "  ✓ Workflow directory created"
fi

# Load sites from config.json or baseline info
CONFIG_FILE="$VALIDATION_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    SITES=$(python3 -c "import json; print(' '.join(json.load(open('$CONFIG_FILE')).get('validation_sites', [])))" 2>/dev/null || echo "")
fi
if [ -z "$SITES" ]; then
    # Fallback to baseline info
    SITES=$(grep "Sites Included" "$BASELINE_DIR/BASELINE_INFO.md" | sed 's/.*: //' || echo "nzd0001 sar0001")
fi
echo -e "${YELLOW}Validation sites: $SITES${NC}"

# Step 1: Copy baseline data to workflow directory
echo -e "\n${YELLOW}Step 1: Copying baseline data to workflow directory...${NC}"
cp "$BASELINE_DIR/transects_extended.geojson" "$WORKFLOW_DIR/"
echo "  ✓ transects_extended.geojson"

# Copy site data directories
for site in $SITES; do
    if [ -d "$BASELINE_DIR/data/$site" ]; then
        echo "  - Copying data for site: $site..."
        mkdir -p "$WORKFLOW_DIR/data/$site"
        cp -r "$BASELINE_DIR/data/$site"/* "$WORKFLOW_DIR/data/$site/" 2>/dev/null || true
        echo "    ✓ $site data copied"
    fi
done

# Step 2: Copy polygons.geojson and shorelines.geojson from original (to include new sites)
echo -e "\n${YELLOW}Step 2: Copying polygons.geojson and shorelines.geojson...${NC}"
ORIGINAL_DIR="$VALIDATION_DIR/../CoastSat-Original"
if [ -f "$ORIGINAL_DIR/polygons.geojson" ]; then
    cp "$ORIGINAL_DIR/polygons.geojson" "$WORKFLOW_DIR/"
    echo "  ✓ polygons.geojson copied from original"
else
    echo -e "${RED}Error: polygons.geojson not found in $ORIGINAL_DIR${NC}"
    exit 1
fi

if [ -f "$ORIGINAL_DIR/shorelines.geojson" ]; then
    cp "$ORIGINAL_DIR/shorelines.geojson" "$WORKFLOW_DIR/"
    echo "  ✓ shorelines.geojson copied from original"
else
    echo -e "${YELLOW}Warning: shorelines.geojson not found in $ORIGINAL_DIR${NC}"
fi

# Step 3: Filter polygons.geojson to only include validation sites
echo -e "\n${YELLOW}Step 3: Filtering polygons.geojson...${NC}"
python3 << EOF
import json
import sys
import os

# Try to load sites from config
sites = "$SITES".split()
config_path = "$VALIDATION_DIR/config.json"
if os.path.exists(config_path):
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
            sites = config.get('validation_sites', sites)
    except:
        pass

# Read the full polygons file
with open("$WORKFLOW_DIR/polygons.geojson", "r") as f:
    polygons = json.load(f)

# Filter features to only include validation sites
filtered_features = [
    feature for feature in polygons["features"]
    if feature["properties"]["id"] in sites
]

if len(filtered_features) == 0:
    print("  ✗ Error: No matching sites found in polygons.geojson")
    sys.exit(1)

# Update the feature collection
polygons["features"] = filtered_features

# Write filtered polygons
with open("$WORKFLOW_DIR/polygons.geojson", "w") as f:
    json.dump(polygons, f, indent=2)

print(f"  ✓ Filtered to {len(filtered_features)} site(s): {', '.join(sites)}")
EOF

# Step 4: Filter shorelines.geojson to only include validation sites
echo -e "\n${YELLOW}Step 4: Filtering shorelines.geojson...${NC}"
if [ -f "$WORKFLOW_DIR/shorelines.geojson" ]; then
    python3 << EOF
import json
import sys
import os

# Try to load sites from config
sites = "$SITES".split()
config_path = "$VALIDATION_DIR/config.json"
if os.path.exists(config_path):
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
            sites = config.get('validation_sites', sites)
    except:
        pass

# Read the full shorelines file
with open("$WORKFLOW_DIR/shorelines.geojson", "r") as f:
    shorelines = json.load(f)

# Filter features to only include validation sites
filtered_features = [
    feature for feature in shorelines["features"]
    if feature["properties"]["id"] in sites
]

if len(filtered_features) == 0:
    print("  ⚠ Warning: No matching sites found in shorelines.geojson")
else:
    # Update the feature collection
    shorelines["features"] = filtered_features
    
    # Write filtered shorelines
    with open("$WORKFLOW_DIR/shorelines.geojson", "w") as f:
        json.dump(shorelines, f, indent=2)
    
    print(f"  ✓ Filtered to {len(filtered_features)} site(s): {', '.join(sites)}")
EOF
else
    echo "  ⚠ shorelines.geojson not found, skipping"
fi

# Step 5: Create validation-specific update script
echo -e "\n${YELLOW}Step 5: Creating validation update script...${NC}"
cat > "$WORKFLOW_DIR/update_validation.sh" << 'UPDATE_SCRIPT'
#!/bin/bash -l
# Validation-specific update script (no git operations)

set -e

echo "Running CoastSat validation workflow..."
echo "========================================"

# Run batch processing
echo -e "\n[1/5] Processing NZ sites..."
./batch_process_NZ.py

echo -e "\n[2/5] Processing SAR sites..."
./batch_process_sar.py

# Run notebooks using safe execution (patches IPython magic issues)
echo -e "\n[3/5] Running tidal correction (first pass)..."
python3 execute_notebook_safe.py tidal_correction.ipynb tidal_correction.ipynb 1800

echo -e "\n[4/5] Running slope estimation..."
python3 execute_notebook_safe.py slope_estimation.ipynb slope_estimation.ipynb 1800

echo -e "\n[5/5] Running tidal correction (second pass)..."
python3 execute_notebook_safe.py tidal_correction.ipynb tidal_correction.ipynb 1800

echo -e "\n[6/6] Running linear models..."
python3 execute_notebook_safe.py linear_models.ipynb linear_models.ipynb 1800

echo -e "\n[7/7] Generating Excel files..."
./make_xlsx.py

echo -e "\n✓ Validation workflow complete!"
echo ""
echo "Next step: Run compare_results.sh from the parent directory to compare results"
UPDATE_SCRIPT

chmod +x "$WORKFLOW_DIR/update_validation.sh"
echo "  ✓ update_validation.sh created"

# Step 6: Create a requirements check script
echo -e "\n${YELLOW}Step 6: Creating requirements check...${NC}"
cat > "$WORKFLOW_DIR/check_requirements.sh" << 'REQ_SCRIPT'
#!/bin/bash
# Check if all requirements are met for running the validation workflow

echo "Checking validation workflow requirements..."
echo "============================================"

ERRORS=0

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "✗ Python 3 not found"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ Python 3 found: $(python3 --version)"
fi

# Check Jupyter
if ! python3 -c "import jupyter" 2>/dev/null; then
    echo "✗ Jupyter not installed (pip install jupyter)"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ Jupyter installed"
fi

# Check required Python packages
REQUIRED_PACKAGES=("geopandas" "pandas" "numpy" "coastsat" "ee")
for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! python3 -c "import $package" 2>/dev/null; then
        echo "✗ $package not installed"
        ERRORS=$((ERRORS + 1))
    else
        echo "✓ $package installed"
    fi
done

# Check for .private-key.json (GEE credentials)
if [ ! -f ".private-key.json" ]; then
    echo "⚠ .private-key.json not found (required for GEE access)"
    echo "  Copy from CoastSat-Original or set up GEE service account"
else
    echo "✓ .private-key.json found"
fi

# Check for transects_extended.geojson
if [ ! -f "transects_extended.geojson" ]; then
    echo "✗ transects_extended.geojson not found (run prepare_workflow.sh first)"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ transects_extended.geojson found"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✓ All requirements met!"
    exit 0
else
    echo "✗ $ERRORS requirement(s) missing"
    echo ""
    echo "Install missing packages with:"
    echo "  pip install -r requirements.txt"
    exit 1
fi
REQ_SCRIPT

chmod +x "$WORKFLOW_DIR/check_requirements.sh"
echo "  ✓ check_requirements.sh created"

# Step 6: Extract max date from validation data and create MAX_DATE.txt
echo -e "\n${YELLOW}Step 6: Setting validation date constraint...${NC}"
VALIDATION_DATA_DIR="$VALIDATION_DIR/validation"
if [ -d "$VALIDATION_DATA_DIR/data" ]; then
    # Use Docker to extract max dates and use the earliest (most conservative)
    MAX_DATE=$(docker compose run --rm coastsat-validation bash -c "cd /app && python3 << 'PYTHON_SCRIPT'
import pandas as pd
from pathlib import Path

sites = '$SITES'.split()
max_dates = []
for site in sites:
    val_path = Path(f'/app/../validation/data/{site}/transect_time_series.csv')
    if val_path.exists():
        try:
            df = pd.read_csv(str(val_path))
            dates = pd.to_datetime(df['dates'])
            max_date = dates.max()
            max_dates.append(max_date)
        except Exception as e:
            pass

if max_dates:
    # Use the earliest max date to ensure no site exceeds validation
    overall_max = min(max_dates)
    print(overall_max.strftime('%Y-%m-%d'))
else:
    # Fallback: use validation commit date from VALIDATION_INFO.md
    print('2025-10-31')
PYTHON_SCRIPT
" 2>/dev/null | tail -1 | tr -d '\r\n')
    
    if [ -n "$MAX_DATE" ]; then
        cat > "$WORKFLOW_DIR/MAX_DATE.txt" << EOF
# Maximum date for image retrieval (validation upper bound)
# This file is automatically generated by prepare_workflow.sh
# Format: YYYY-MM-DD
# This ensures deterministic validation by constraining image retrieval
# to dates present in the validation dataset
# Uses the earliest max date across all validation sites
$MAX_DATE
EOF
        echo "  ✓ MAX_DATE.txt created with max date: $MAX_DATE"
        echo "    This constrains all sites to this date (earliest validation max date)"
    else
        echo "  ⚠ Could not determine max date, using default"
    fi
else
    echo "  ⚠ Validation data not found, skipping MAX_DATE.txt creation"
fi

echo -e "\n${GREEN}✓ Workflow preparation complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. cd workflow"
echo "  2. ./check_requirements.sh  # Verify all dependencies"
echo "  3. ./update_validation.sh    # Run the validation workflow"
echo "  4. cd .."
echo "  5. ./compare_results.sh       # Compare results with validation data"

