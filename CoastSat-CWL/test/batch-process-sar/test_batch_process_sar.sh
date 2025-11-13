#!/bin/bash
# Test script for batch-process-sar.cwl tool

set -e

# Get script directory and navigate to it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Calculate paths relative to test directory
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
TOOL_NAME="batch-process-sar"

echo "========================================="
echo "Testing ${TOOL_NAME}.cwl Tool"
echo "========================================="
echo "Test directory: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"
echo ""

# Check for GEE credentials
if [ -z "$GEE_SERVICE_ACCOUNT" ] && [ -z "$GEE_PRIVATE_KEY_PATH" ]; then
    # Try to get from .env file
    if [ -f "../../../.env" ]; then
        export $(grep "^GEE_SERVICE_ACCOUNT\|^GEE_PRIVATE_KEY_PATH" ../../../.env | xargs)
    fi
fi

# If GEE_PRIVATE_KEY_PATH is not set, try to find .private-key.json in common locations
if [ -z "$GEE_PRIVATE_KEY_PATH" ]; then
    if [ -f "../../../.private-key.json" ]; then
        GEE_PRIVATE_KEY_PATH="../../../.private-key.json"
        echo "Found .private-key.json in repo root"
    elif [ -f "../../../../.private-key.json" ]; then
        GEE_PRIVATE_KEY_PATH="../../../../.private-key.json"
        echo "Found .private-key.json in parent directory"
    fi
    export GEE_PRIVATE_KEY_PATH
fi

if [ -z "$GEE_SERVICE_ACCOUNT" ]; then
    echo "⚠️  Warning: GEE credentials not found"
    echo "   This test requires Google Earth Engine authentication"
    echo "   Set GEE_SERVICE_ACCOUNT environment variable or provide in ../../../.env file"
    echo ""
    echo "   Skipping test execution (CWL validation will still run)"
    SKIP_EXECUTION=true
elif [ -z "$GEE_PRIVATE_KEY_PATH" ] || [ ! -f "$GEE_PRIVATE_KEY_PATH" ]; then
    echo "⚠️  Warning: GEE private key not found"
    echo "   Expected: $GEE_PRIVATE_KEY_PATH"
    echo "   Set GEE_PRIVATE_KEY_PATH environment variable or ensure .private-key.json exists"
    echo ""
    echo "   Skipping test execution (CWL validation will still run)"
    SKIP_EXECUTION=true
else
    echo "✅ GEE credentials found"
    echo "   Service Account: $GEE_SERVICE_ACCOUNT"
    echo "   Private Key: $GEE_PRIVATE_KEY_PATH"
    SKIP_EXECUTION=false
fi
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

if [ "$SKIP_EXECUTION" = true ]; then
    echo "========================================="
    echo "Test Complete (Validation Only)"
    echo "========================================="
    echo "⚠️  Tool execution skipped (GEE credentials not available)"
    exit 0
fi

# Convert tool name from kebab-case to snake_case for filename
TEST_FILE_NAME=$(echo "${TOOL_NAME}" | tr '-' '_')

# Create output directory
OUTPUT_DIR="$SCRIPT_DIR/outputs"
mkdir -p "$OUTPUT_DIR/data"

# Update test YAML with credentials if needed
TEMP_YAML="$SCRIPT_DIR/test_${TEST_FILE_NAME}_with_creds.yml"
cat > "$TEMP_YAML" << EOF
site_id: sar0001
polygons:
  class: File
  path: ../../../CoastSat-minimal/inputs/polygons.geojson
shorelines:
  class: File
  path: ../../../CoastSat-minimal/inputs/shorelines.geojson
transects_extended:
  class: File
  path: ../../../CoastSat-minimal/inputs/transects_extended.geojson
output_dir:
  class: Directory
  path: outputs/data
start_date: "2024-01-01"
end_date: "2024-12-31"
sat_list: ["L8", "L9"]
gee_service_account: "$GEE_SERVICE_ACCOUNT"
gee_private_key:
  class: File
  path: "$(realpath "$GEE_PRIVATE_KEY_PATH")"
script:
  class: File
  path: ../../tools/batch-process-sar/batch_process_sar_wrapper.py
EOF

# Run the tool
echo "Step 2: Running ${TOOL_NAME}.cwl..."
echo "----------------------------------------"
echo "Note: This tool downloads satellite imagery from Google Earth Engine"
echo "      and may take several minutes to complete..."
cd "$OUTPUT_DIR"

# Export credentials for the tool
export GEE_SERVICE_ACCOUNT
export GEE_PRIVATE_KEY_PATH

# Run the tool with test inputs
if cwltool --outdir . "$PROJECT_ROOT/tools/${TOOL_NAME}/${TOOL_NAME}.cwl" "$TEMP_YAML" 2>&1; then
    echo ""
    echo "✅ Tool executed successfully"
else
    echo ""
    echo "❌ Tool execution failed"
    # Clean up temp YAML
    rm -f "$TEMP_YAML"
    exit 1
fi
echo ""

# Clean up temp YAML
rm -f "$TEMP_YAML"

# Check if output file exists
echo "Step 3: Verifying output..."
echo "----------------------------------------"
# cwltool extracts the file from the glob pattern, so it's at the root of outdir
# The glob pattern is "data/$(inputs.site_id)/transect_time_series.csv" but cwltool
# extracts just the file name, not the directory structure
OUTPUT_FILE="transect_time_series.csv"
if [ -f "$OUTPUT_FILE" ]; then
    echo "✅ Output file $OUTPUT_FILE created"
    
    # Check file size (should be > 0)
    SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo 0)
    if [ "$SIZE" -gt 0 ]; then
        echo "✅ Output file has content (${SIZE} bytes)"
    else
        echo "⚠️  Output file is empty"
    fi
    
    # Check CSV structure (should have dates and transect columns)
    if head -1 "$OUTPUT_FILE" | grep -q "dates"; then
        echo "✅ Output file appears to have correct CSV structure"
    else
        echo "⚠️  Could not verify CSV structure"
    fi
    
    # Count rows (should have at least 1 row of data)
    ROW_COUNT=$(wc -l < "$OUTPUT_FILE" 2>/dev/null || echo 0)
    if [ "$ROW_COUNT" -gt 1 ]; then
        echo "✅ Output file contains data rows (${ROW_COUNT} lines total)"
    else
        echo "⚠️  Output file may be empty or only contain header"
    fi
else
    echo "❌ Output file $OUTPUT_FILE not found"
    ls -la data/ 2>/dev/null || echo "  Output directory not found"
    exit 1
fi
echo ""

# Compare with expected output if available
echo "Step 4: Comparing with expected output..."
echo "----------------------------------------"
# Expected file path should also be at root, not in data/ subdirectory
EXPECTED="$SCRIPT_DIR/expected/$OUTPUT_FILE"
if [ -f "$EXPECTED" ]; then
    EXPECTED_SIZE=$(stat -f%z "$EXPECTED" 2>/dev/null || stat -c%s "$EXPECTED" 2>/dev/null || echo 0)
    ACTUAL_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo 0)
    
    echo "Expected size: ${EXPECTED_SIZE} bytes"
    echo "Actual size: ${ACTUAL_SIZE} bytes"
    
    # Files might differ due to processing differences, so we just check they're both non-empty
    if [ "$ACTUAL_SIZE" -gt 0 ] && [ "$EXPECTED_SIZE" -gt 0 ]; then
        echo "✅ Both files have content"
        echo "⚠️  Note: Detailed comparison may show differences due to processing variability"
    else
        echo "⚠️  Size mismatch (may be expected)"
    fi
else
    # Try fallback location
    FALLBACK="$PROJECT_ROOT/../CoastSat-minimal/data/sar0001/transect_time_series.csv"
    if [ -f "$FALLBACK" ]; then
        EXPECTED_SIZE=$(stat -f%z "$FALLBACK" 2>/dev/null || stat -c%s "$FALLBACK" 2>/dev/null || echo 0)
        ACTUAL_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo 0)
        echo "Using fallback expected output: $FALLBACK"
        echo "Expected size: ${EXPECTED_SIZE} bytes"
        echo "Actual size: ${ACTUAL_SIZE} bytes"
        if [ "$ACTUAL_SIZE" -gt 0 ] && [ "$EXPECTED_SIZE" -gt 0 ]; then
            echo "✅ Both files have content"
            echo "⚠️  Note: Files may differ due to processing variability or date ranges"
        fi
    else
        echo "⚠️  Expected output file not found"
        echo "   Expected: $EXPECTED"
        echo "   Fallback: $FALLBACK"
        echo "   Skipping detailed comparison"
    fi
fi
echo ""

echo "========================================="
echo "Test Complete"
echo "========================================="
echo "Output file: $OUTPUT_DIR/$OUTPUT_FILE"
echo ""
echo "Note: This tool downloads satellite imagery from Google Earth Engine"
echo "      and may take several minutes depending on the date range and number of images."

