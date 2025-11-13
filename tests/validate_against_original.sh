#!/bin/bash
# Script to validate new workflow against original CoastSat data
# This script configures the new workflow to match the original data exactly

set -e  # Exit on error

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================="
echo "Validation Against Original CoastSat Data"
echo "========================================="
echo "Project root: $PROJECT_ROOT"
echo ""

# Check if original data exists
if [ ! -d "CoastSat/data/nzd0001" ]; then
    echo "❌ Error: Original CoastSat data not found"
    echo "Please ensure the original CoastSat data is in CoastSat/data/nzd0001/"
    exit 1
fi

# Step 1: Extract configuration from original data
echo "Step 1: Extracting configuration from original data..."
python3 tests/extract_original_config.py --site nzd0001

# Step 2: Backup existing .env file
if [ -f ".env" ]; then
    echo ""
    echo "Step 2: Backing up existing .env file..."
    cp .env .env.backup
    echo "Backed up to .env.backup"
fi

# Step 3: Generate validation configuration
echo ""
echo "Step 3: Generating validation configuration..."
python3 tests/extract_original_config.py --site nzd0001 --output validation_config.env

# Step 4: Merge with existing .env (or create new)
echo ""
echo "Step 4: Setting up .env for validation..."
if [ -f ".env" ]; then
    echo "Merging validation configuration with existing .env..."
    # Extract non-validation config from .env
    grep -v "^TEST_MODE" .env | grep -v "^TEST_START_DATE" | grep -v "^TEST_END_DATE" | grep -v "^TEST_SITES" | grep -v "^TEST_SATELLITES" > .env.tmp || true
    # Add validation config
    grep "^TEST_" validation_config.env >> .env.tmp || true
    # Add other required config from original .env
    grep "^NIWA_TIDE_API_KEY" .env >> .env.tmp || true
    grep "^GEE_SERVICE_ACCOUNT" .env >> .env.tmp || true
    mv .env.tmp .env
else
    echo "Creating new .env from validation configuration..."
    cp validation_config.env .env
    echo ""
    echo "⚠️  WARNING: .env file created from validation config"
    echo "   Please add your API keys:"
    echo "   - NIWA_TIDE_API_KEY=your_key"
    echo "   - GEE_SERVICE_ACCOUNT=your_service_account"
fi

# Step 5: Show configuration
echo ""
echo "Step 5: Validation configuration:"
echo "----------------------------------------"
grep "^TEST_" .env | head -10 || echo "No TEST_ configuration found"
echo ""

# Step 6: Clean existing data for nzd0001 (optional)
echo "Step 6: Cleaning existing data for nzd0001..."
read -p "Do you want to clean existing data for nzd0001? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing existing data for nzd0001..."
    rm -rf data/nzd0001/*
    echo "Cleaned data/nzd0001/"
else
    echo "Skipping data cleanup"
fi

# Step 7: Run new workflow
echo ""
echo "Step 7: Running new workflow..."
echo "----------------------------------------"
echo "This will process nzd0001 with the same configuration as the original data"
echo ""
read -p "Continue? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    ./workflow/workflow.sh
else
    echo "Skipping workflow execution"
    echo "Run manually: ./workflow/workflow.sh"
fi

# Step 8: Compare results
echo ""
echo "Step 8: Comparing results..."
echo "----------------------------------------"
python3 tests/compare_with_original.py --sites nzd0001 --output validation_report.txt

# Step 9: Show summary
echo ""
echo "========================================="
echo "Validation Complete"
echo "========================================="
echo ""
echo "Comparison report saved to: validation_report.txt"
echo ""
echo "To review the report:"
echo "  cat validation_report.txt"
echo ""
echo "To restore original .env:"
echo "  cp .env.backup .env"
echo ""

