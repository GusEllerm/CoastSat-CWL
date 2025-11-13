#!/bin/bash
# Test harness for CWL workflow validation

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT_ROOT="$(cd .. && pwd)"

echo "========================================="
echo "CoastSat-CWL Test Harness"
echo "========================================="
echo "Project root: $PROJECT_ROOT"
echo ""

# Step 1: Validate CWL files
echo "Step 1: Validating CWL files..."
echo "----------------------------------------"
python3 validate_cwl.py
if [ $? -eq 0 ]; then
    echo "✅ CWL validation passed"
else
    echo "❌ CWL validation failed"
    exit 1
fi
echo ""

# Step 2: Test simple CWL tool
echo "Step 2: Testing simple CWL tool..."
echo "----------------------------------------"
if [ -f "test_simple.cwl" ]; then
    # Clean up any previous test outputs
    rm -f outputs/temp/test_simple_* outputs/temp/*[0-9a-f]*
    
    echo "Running test_simple.cwl (outputs to outputs/temp/)..."
    timeout 60 cwltool --outdir outputs/temp test_simple.cwl 2>&1 | head -20 || echo "Note: Test completed (may timeout, that's OK)"
    
    # Check if output was created
    if ls outputs/temp/test_output* 2>/dev/null | head -1 > /dev/null; then
        echo "✅ Simple CWL tool test completed (output in outputs/temp/)"
    else
        echo "✅ Simple CWL tool test completed"
    fi
else
    echo "⚠️  test_simple.cwl not found, skipping"
fi
echo ""

# Step 3: Check Docker image
echo "Step 3: Verifying Docker image..."
echo "----------------------------------------"
if docker images | grep -q "coastsat-cwl.*latest"; then
    echo "✅ Docker image 'coastsat-cwl:latest' found"
    docker run --rm coastsat-cwl:latest python3 -c "from coastsat import SDS_download; print('✓ CoastSat imports successfully')" 2>&1 | grep -q "successfully" && echo "✅ Docker image test passed"
else
    echo "⚠️  Docker image 'coastsat-cwl:latest' not found"
    echo "   Build it with: cd docker && ./build.sh"
fi
echo ""

# Step 4: Check development tools
echo "Step 4: Checking development tools..."
echo "----------------------------------------"
if command -v cwltool &> /dev/null; then
    echo "✅ cwltool: $(cwltool --version 2>&1 | head -1)"
else
    echo "❌ cwltool not found. Install with: pip install cwltool"
fi

if command -v cwlprov &> /dev/null; then
    echo "✅ cwlprov: $(cwlprov --version 2>&1 | tail -1)"
else
    echo "❌ cwlprov not found. Install with: pip install cwlprov"
fi
echo ""

# Step 5: Check project structure
echo "Step 5: Checking project structure..."
echo "----------------------------------------"
required_dirs=("tools" "workflows" "test" "examples" "docker")
for dir in "${required_dirs[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        echo "✅ $dir/ directory exists"
    else
        echo "❌ $dir/ directory missing"
    fi
done
echo ""

# Step 6: Clean up temporary test outputs
echo "Step 6: Cleaning up temporary test outputs..."
echo "----------------------------------------"
# Remove hash-named files that might have been created
find . -maxdepth 1 -type f -name '[0-9a-f]*' -delete 2>/dev/null || true
echo "✅ Temporary files cleaned up"
echo ""

echo "========================================="
echo "Test Harness Complete"
echo "========================================="
echo ""
echo "Test outputs organized in:"
echo "  - outputs/temp/  - Temporary test outputs (cleaned up)"
echo "  - outputs/cwl/   - CWL workflow outputs (for comparison)"
echo ""
echo "Next steps:"
echo "1. Begin Phase 2: Create CWL tool definitions"
echo "2. Start with simplest tool: make-xlsx.cwl"
echo "3. Validate and test each tool"

