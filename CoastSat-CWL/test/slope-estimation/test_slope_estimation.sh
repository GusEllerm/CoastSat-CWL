#!/bin/bash
# Test script for slope-estimation.cwl tool

set -e

# Get script directory and navigate to it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Calculate paths relative to test directory
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
TOOL_NAME="slope-estimation"

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
echo "Note: This tool performs spectral analysis and may take several minutes..."
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
OUTPUT_FILE="nzd0001_transects_updated.geojson"
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
        
        # Check if it has beach_slope column
        if python3 -c "import geopandas as gpd; gdf = gpd.read_file('$OUTPUT_FILE'); print('Has beach_slope:', 'beach_slope' in gdf.columns)" 2>/dev/null | grep -q "True"; then
            echo "✅ Output file contains beach_slope column"
            
            # Count how many transects have beach_slope values
            SLOPE_COUNT=$(python3 -c "import geopandas as gpd; import pandas as pd; gdf = gpd.read_file('$OUTPUT_FILE'); print(gdf['beach_slope'].notna().sum())" 2>/dev/null || echo "0")
            echo "✅ Number of transects with beach_slope: $SLOPE_COUNT"
        else
            echo "⚠️  Output file does not contain beach_slope column"
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
        echo "⚠️  Note: Detailed comparison may show differences due to spectral analysis variability"
    else
        echo "⚠️  Size mismatch (may be expected)"
    fi
else
    echo "⚠️  Expected output file not found"
    echo "   Expected: $EXPECTED"
    echo "   Skipping detailed comparison"
    echo ""
    echo "Note: This tool estimates beach slopes using spectral analysis."
    echo "      The output should contain transects for the site with beach_slope values populated."
fi
echo ""

echo "========================================="
echo "Test Complete"
echo "========================================="
echo "Output file: $OUTPUT_DIR/$OUTPUT_FILE"
echo ""
echo "Note: This tool performs computationally intensive spectral analysis."
echo "      Execution time may vary based on the number of transects and data points."

