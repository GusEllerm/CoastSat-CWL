#!/bin/bash
# Script to validate new workflow against original CoastSat data for nzd0001
# This script configures the new workflow to match the original data exactly

set -e  # Exit on error

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================="
echo "Validation: nzd0001 Against Original Data"
echo "========================================="
echo "Project root: $PROJECT_ROOT"
echo ""

# Check if original data exists
if [ ! -f "CoastSat/data/nzd0001/transect_time_series.csv" ]; then
    echo "❌ Error: Original CoastSat data not found"
    echo "Please ensure the original CoastSat data is in CoastSat/data/nzd0001/"
    exit 1
fi

# Step 1: Extract configuration from original data
echo "Step 1: Extracting configuration from original data..."
python3 tests/extract_original_config.py --site nzd0001 --json --output original_config.json

# Read configuration
START_DATE=$(python3 -c "import json; print(json.load(open('original_config.json'))['date_range']['start'])")
END_DATE=$(python3 -c "import json; print(json.load(open('original_config.json'))['date_range']['end'])")
SATELLITES=$(python3 -c "import json; print(','.join(json.load(open('original_config.json'))['satellites']['list']))")
NUM_ROWS=$(python3 -c "import json; print(json.load(open('original_config.json'))['num_rows'])")

echo ""
echo "Original data configuration:"
echo "  Date range: $START_DATE to $END_DATE"
echo "  Satellites: $SATELLITES"
echo "  Number of rows: $NUM_ROWS"
echo ""

# Step 2: Backup existing .env file
if [ -f ".env" ]; then
    echo "Step 2: Backing up existing .env file..."
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    echo "Backed up to .env.backup.*"
else
    echo "Step 2: No existing .env file found"
fi

# Step 3: Create validation .env file
echo ""
echo "Step 3: Creating validation .env file..."
cat > .env.validation <<EOF
# Validation Configuration for nzd0001
# This configuration matches the original CoastSat data

# Use exact date range from original data
TEST_MODE=true
TEST_START_DATE=$START_DATE
TEST_END_DATE=$END_DATE

# Force start date to match original data exactly (overrides incremental processing)
FORCE_START_DATE=$START_DATE

# Process only nzd0001
TEST_SITES=nzd0001

# Use same satellites as original
TEST_SATELLITES=$SATELLITES

# Original data configuration:
# - Date range: $START_DATE to $END_DATE
# - Satellites: $SATELLITES
# - Number of rows: $NUM_ROWS
# - Landsat collection: C02
EOF

# Merge with existing .env (preserve API keys)
if [ -f ".env" ]; then
    echo "Merging validation configuration with existing .env..."
    # Extract API keys and other non-validation config
    grep "^NIWA_TIDE_API_KEY" .env > .env.tmp 2>/dev/null || true
    grep "^GEE_SERVICE_ACCOUNT" .env >> .env.tmp 2>/dev/null || true
    grep "^GEE_PRIVATE_KEY_PATH" .env >> .env.tmp 2>/dev/null || true
    # Add validation config
    grep "^TEST_" .env.validation >> .env.tmp
    grep "^FORCE_START_DATE" .env.validation >> .env.tmp
    mv .env.tmp .env
    echo "Updated .env with validation configuration"
else
    echo "⚠️  WARNING: No .env file found. Creating from validation config."
    echo "   Please add your API keys manually:"
    echo "   - NIWA_TIDE_API_KEY=your_key"
    echo "   - GEE_SERVICE_ACCOUNT=your_service_account"
    cp .env.validation .env
fi

# Step 4: Show configuration
echo ""
echo "Step 4: Validation configuration:"
echo "----------------------------------------"
echo "TEST_MODE=$(grep "^TEST_MODE" .env | cut -d'=' -f2)"
echo "TEST_START_DATE=$(grep "^TEST_START_DATE" .env | cut -d'=' -f2)"
echo "TEST_END_DATE=$(grep "^TEST_END_DATE" .env | cut -d'=' -f2)"
echo "TEST_SITES=$(grep "^TEST_SITES" .env | cut -d'=' -f2)"
echo "TEST_SATELLITES=$(grep "^TEST_SATELLITES" .env | cut -d'=' -f2)"
echo ""

# Step 5: Clean existing data for nzd0001
echo "Step 5: Cleaning existing data for nzd0001..."
echo "⚠️  WARNING: This will delete existing data for nzd0001"
read -p "Do you want to clean existing data? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing existing data for nzd0001..."
    rm -rf data/nzd0001/*
    echo "✅ Cleaned data/nzd0001/"
else
    echo "Skipping data cleanup (existing data will be used/updated)"
fi

# Step 6: Run new workflow
echo ""
echo "Step 6: Running new workflow..."
echo "----------------------------------------"
echo "This will process nzd0001 with the same configuration as the original data"
echo "Expected: ~$NUM_ROWS rows of data"
echo ""
read -p "Continue? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Running workflow..."
    ./workflow/workflow.sh
    echo ""
    echo "✅ Workflow completed"
else
    echo "Skipping workflow execution"
    echo "Run manually: ./workflow/workflow.sh"
    exit 0
fi

# Step 7: Compare results
echo ""
echo "Step 7: Comparing results..."
echo "----------------------------------------"
python3 tests/compare_with_original.py --sites nzd0001 --output validation_report_nzd0001.txt

# Step 8: Show summary
echo ""
echo "========================================="
echo "Validation Complete"
echo "========================================="
echo ""
echo "Comparison report saved to: validation_report_nzd0001.txt"
echo ""
echo "To review the report:"
echo "  cat validation_report_nzd0001.txt"
echo ""
echo "Expected results:"
echo "  - transect_time_series.csv: Should match exactly (194 rows)"
echo "  - tides.csv: Should match exactly (194 rows)"
echo "  - transect_time_series_tidally_corrected.csv: Should match closely"
echo "  - transects_extended.geojson: Should match closely (beach_slope, trend, etc.)"
echo ""
echo "To restore original .env:"
echo "  cp .env.backup.* .env"
echo ""

