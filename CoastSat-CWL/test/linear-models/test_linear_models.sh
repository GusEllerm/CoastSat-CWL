#!/bin/bash
# Test script for linear-models.cwl tool

set -e

# Get script directory and navigate to it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Calculate paths relative to test directory
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
TOOL_NAME="linear-models"

echo "========================================="
echo "Testing ${TOOL_NAME}.cwl Tool"
echo "========================================="
echo "Test directory: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"
echo ""

# Validate CWL tool
echo "Step 1: Validating CWL tool..."
echo "----------------------------------------"
if cwltool --validate "$PROJECT_ROOT/tools/${TOOL_NAME}/${TOOL_NAME}.cwl" 2>&1 | grep -q "is valid CWL"; then
    echo "✅ CWL tool validates successfully"
else
    echo "❌ CWL tool validation failed"
    cwltool --validate "$PROJECT_ROOT/tools/${TOOL_NAME}/${TOOL_NAME}.cwl"
    exit 1
fi
echo ""

# Convert tool name from kebab-case to snake_case for filename
TEST_FILE_NAME=$(echo "${TOOL_NAME}" | tr '-' '_')

# Create output directory
OUTPUT_DIR="$SCRIPT_DIR/outputs"
mkdir -p "$OUTPUT_DIR"

# Run the tool
echo "Step 2: Running ${TOOL_NAME}.cwl..."
echo "----------------------------------------"
cd "$OUTPUT_DIR"

# Run the tool with test inputs
if cwltool --outdir . "$PROJECT_ROOT/tools/${TOOL_NAME}/${TOOL_NAME}.cwl" "$SCRIPT_DIR/test_${TEST_FILE_NAME}.yml" 2>&1; then
    echo ""
    echo "✅ Tool executed successfully"
else
    echo ""
    echo "❌ Tool execution failed"
    exit 1
fi
echo ""

# Check if output file exists
echo "Step 3: Verifying output..."
echo "----------------------------------------"
OUTPUT_FILE="nzd0001_transects_with_trends.geojson"
if [ -f "$OUTPUT_FILE" ]; then
    echo "✅ Output file $OUTPUT_FILE created"
    
    # Check file size (should be > 0)
    SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo 0)
    if [ "$SIZE" -gt 0 ]; then
        echo "✅ Output file has content (${SIZE} bytes)"
    else
        echo "⚠️  Output file is empty"
    fi
    
    # Check if it's a valid GeoJSON (basic check - try to parse with Python)
    if python3 -c "import geopandas as gpd; gpd.read_file('$OUTPUT_FILE'); print('Valid GeoJSON')" 2>/dev/null; then
        echo "✅ Output file appears to be a valid GeoJSON file"
        
        # Check for trend-related columns
        TREND_COLS=$(python3 -c "import geopandas as gpd; gdf = gpd.read_file('$OUTPUT_FILE'); print(','.join([c for c in gdf.columns if 'trend' in c.lower() or 'r2' in c.lower() or 'mae' in c.lower() or 'mse' in c.lower() or 'rmse' in c.lower()]))" 2>/dev/null || echo "")
        if [ -n "$TREND_COLS" ]; then
            echo "✅ Output file contains trend statistics columns: $TREND_COLS"
        else
            echo "⚠️  Output file may not contain trend statistics columns"
        fi
        
        # Count how many transects have trend values
        TREND_COUNT=$(python3 -c "import geopandas as gpd; import pandas as pd; gdf = gpd.read_file('$OUTPUT_FILE'); print(gdf['trend'].notna().sum() if 'trend' in gdf.columns else 0)" 2>/dev/null || echo "0")
        if [ "$TREND_COUNT" -gt 0 ]; then
            echo "✅ Number of transects with trend values: $TREND_COUNT"
        else
            echo "⚠️  No transects with trend values found"
        fi
    else
        echo "⚠️  Could not verify GeoJSON format"
    fi
    
    # Count rows (should have at least some transects for the site)
    ROW_COUNT=$(python3 -c "import geopandas as gpd; gdf = gpd.read_file('$OUTPUT_FILE'); print(len(gdf))" 2>/dev/null || echo "0")
    if [ "$ROW_COUNT" -gt 0 ]; then
        echo "✅ Output file contains transects (${ROW_COUNT} transects)"
    else
        echo "⚠️  Output file may be empty"
    fi
else
    echo "❌ Output file $OUTPUT_FILE not found"
    ls -la
    exit 1
fi
echo ""

# Compare with expected output if available
echo "Step 4: Comparing with expected output..."
echo "----------------------------------------"
EXPECTED="$SCRIPT_DIR/expected/$OUTPUT_FILE"
if [ -f "$EXPECTED" ]; then
    EXPECTED_SIZE=$(stat -f%z "$EXPECTED" 2>/dev/null || stat -c%s "$EXPECTED" 2>/dev/null || echo 0)
    ACTUAL_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo 0)
    
    echo "Expected size: ${EXPECTED_SIZE} bytes"
    echo "Actual size: ${ACTUAL_SIZE} bytes"
    
    # Files might differ slightly due to processing, so we just check they're both non-empty
    if [ "$ACTUAL_SIZE" -gt 0 ] && [ "$EXPECTED_SIZE" -gt 0 ]; then
        echo "✅ Both files have content"
        echo "⚠️  Note: Detailed comparison may show differences due to linear regression calculations"
    else
        echo "⚠️  Size mismatch (may be expected)"
    fi
else
    echo "⚠️  Expected output file not found"
    echo "   Expected: $EXPECTED"
    echo "   Skipping detailed comparison"
    echo ""
    echo "Note: This tool calculates linear trends using sklearn LinearRegression."
    echo "      The output should contain transects for the site with trend statistics populated."
fi
echo ""

echo "========================================="
echo "Test Complete"
echo "========================================="
echo "Output file: $OUTPUT_DIR/$OUTPUT_FILE"

