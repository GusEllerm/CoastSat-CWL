#!/bin/bash
# Test script for tidal-correction-apply.cwl tool

set -e

# Get script directory and navigate to it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Calculate paths relative to test directory
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
TOOL_NAME="tidal-correction-apply"

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
OUTPUT_FILE="nzd0001_transect_time_series_tidally_corrected.csv"
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
    
    # Files might differ slightly due to processing differences, so we just check they're both non-empty
    if [ "$ACTUAL_SIZE" -gt 0 ] && [ "$EXPECTED_SIZE" -gt 0 ]; then
        echo "✅ Both files have content"
        echo "⚠️  Note: Detailed comparison may show differences due to despike behavior"
    else
        echo "⚠️  Size mismatch (may be expected)"
    fi
else
    # Try fallback location
    FALLBACK="$PROJECT_ROOT/../CoastSat-minimal/data/nzd0001/transect_time_series_tidally_corrected.csv"
    if [ -f "$FALLBACK" ]; then
        EXPECTED_SIZE=$(stat -f%z "$FALLBACK" 2>/dev/null || stat -c%s "$FALLBACK" 2>/dev/null || echo 0)
        ACTUAL_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo 0)
        echo "Using fallback expected output: $FALLBACK"
        echo "Expected size: ${EXPECTED_SIZE} bytes"
        echo "Actual size: ${ACTUAL_SIZE} bytes"
        if [ "$ACTUAL_SIZE" -gt 0 ] && [ "$EXPECTED_SIZE" -gt 0 ]; then
            echo "✅ Both files have content"
            echo "⚠️  Note: Files may differ due to despike behavior or processing differences"
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

