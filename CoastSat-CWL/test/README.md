# Test Directory

This directory contains test utilities and validation scripts for the CoastSat-CWL workflow.

## Directory Structure

The test directory is organized with per-tool subdirectories. **All inputs, expected outputs, and outputs are within tool-specific subdirectories** - there are no top-level `inputs/`, `expected/`, or `outputs/` directories.

```
test/
├── README.md                 # This file
├── validate_cwl.py           # Validates CWL tool and workflow files
├── compare_outputs.py        # Compares CWL outputs with CoastSat-minimal
├── run_cwl_workflow.py       # Executes CWL workflows
├── test_harness.sh           # Comprehensive test suite
├── cleanup.sh                # Cleanup script for test outputs
├── simple/                   # General CWL test tool
│   ├── README.md
│   ├── test_simple.cwl       # Simple test tool
│   ├── inputs/               # Tool-specific inputs (optional)
│   ├── expected/             # Tool-specific expected outputs (optional)
│   └── outputs/              # Tool-specific outputs (gitignored)
├── make-xlsx/                # Example: make-xlsx tool tests
│   ├── README.md
│   ├── test_make_xlsx.yml    # Test input file
│   ├── test_make_xlsx.sh     # Test script
│   ├── inputs/               # Tool-specific inputs (optional)
│   ├── expected/             # Tool-specific expected outputs (optional)
│   └── outputs/              # Tool-specific outputs (gitignored)
└── <tool-name>/              # Per-tool test directory
    ├── README.md
    ├── test_<tool-name>.yml  # Test input file (if applicable)
    ├── test_<tool-name>.sh  # Test script (if applicable)
    ├── test_<tool-name>.cwl  # CWL test tool (if applicable)
    ├── inputs/               # Tool-specific inputs (optional)
    ├── expected/             # Tool-specific expected outputs (optional)
    └── outputs/              # Tool-specific outputs (gitignored)
```

## Test Utilities

### Global Test Scripts

- **`validate_cwl.py`** - Validates all CWL tool and workflow files for syntax errors
- **`compare_outputs.py`** - Compares CWL workflow outputs with CoastSat-minimal outputs
- **`run_cwl_workflow.py`** - Executes CWL workflows and collects outputs
- **`test_harness.sh`** - Comprehensive test suite that validates environment, tools, and structure
- **`cleanup.sh`** - Removes test outputs and temporary files while preserving directory structure

## Running Tests

### Validate CWL Files

```bash
cd CoastSat-CWL
python3 test/validate_cwl.py
```

Validates all `.cwl` files in `tools/` and `workflows/` directories.

### Run Test Harness

```bash
cd CoastSat-CWL
./test/test_harness.sh
```

Runs comprehensive tests:
- Validates CWL files
- Tests simple CWL tool
- Verifies Docker image
- Checks development tools
- Validates project structure
- Runs individual tool tests

### Run Individual Tool Tests

Each tool has its own test script in `test/<tool-name>/`:

```bash
# Run make-xlsx tool tests
cd CoastSat-CWL
./test/make-xlsx/test_make_xlsx.sh
```

Or from the tool test directory:

```bash
cd test/make-xlsx
./test_make_xlsx.sh
```

### Run Simple CWL Test

```bash
cd CoastSat-CWL
cwltool --outdir test/simple/outputs test/simple/test_simple.cwl
```

Tests that the Docker image and CWL environment work correctly.

### Cleanup Test Outputs

```bash
cd CoastSat-CWL
./test/cleanup.sh
```

Removes temporary test outputs and hash-named files while preserving directory structure.

## Adding a New Tool Test

### Step 1: Create Tool Test Directory

```bash
cd test
mkdir -p <tool-name>/inputs <tool-name>/expected <tool-name>/outputs
touch <tool-name>/outputs/.gitkeep
```

Example for `tidal-correction-fetch`:
```bash
mkdir -p tidal-correction-fetch/inputs tidal-correction-fetch/expected tidal-correction-fetch/outputs
touch tidal-correction-fetch/outputs/.gitkeep
```

### Step 2: Create Test Input File

Create `test/<tool-name>/test_<tool_name>.yml` (use underscores in filename):

```yaml
# Example: test/tidal-correction-fetch/test_tidal_correction_fetch.yml
input1:
  class: File
  path: ../../../CoastSat-minimal/data/input1.csv
input2:
  class: File
  path: ../../../CoastSat-minimal/inputs/input2.geojson
param1: value1
param2: value2
script:
  class: File
  path: ../../tools/tool_wrapper.py
```

**Path Conventions:**
- `../../../` goes up to project root from tool test directory
- `../../tools/` references CWL tool wrapper scripts
- `../` references sibling test directories

### Step 3: Create Test Script

Create `test/<tool-name>/test_<tool_name>.sh`:

```bash
#!/bin/bash
# Test script for <tool-name>.cwl tool

set -e

# Get script directory and navigate to it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Calculate paths relative to test directory
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
TOOL_NAME="<tool-name>"

echo "========================================="
echo "Testing ${TOOL_NAME}.cwl Tool"
echo "========================================="
echo ""

# Validate CWL tool
echo "Step 1: Validating CWL tool..."
if cwltool --validate "$PROJECT_ROOT/tools/${TOOL_NAME}.cwl" 2>&1 | grep -q "is valid CWL"; then
    echo "✅ CWL tool validates successfully"
else
    echo "❌ CWL tool validation failed"
    cwltool --validate "$PROJECT_ROOT/tools/${TOOL_NAME}.cwl"
    exit 1
fi
echo ""

# Create output directory
OUTPUT_DIR="$SCRIPT_DIR/outputs"
mkdir -p "$OUTPUT_DIR"

# Run the tool
echo "Step 2: Running ${TOOL_NAME}.cwl..."
cd "$OUTPUT_DIR"

# Convert tool name from kebab-case to snake_case for filename
TEST_FILE_NAME=$(echo "${TOOL_NAME}" | tr '-' '_')

# Run the tool with test inputs
if cwltool --outdir . "$PROJECT_ROOT/tools/${TOOL_NAME}.cwl" "$SCRIPT_DIR/test_${TEST_FILE_NAME}.yml" 2>&1; then
    echo "✅ Tool executed successfully"
else
    echo "❌ Tool execution failed"
    exit 1
fi
echo ""

# Verify outputs (customize for your tool)
echo "Step 3: Verifying output..."
# TODO: Add tool-specific output verification
echo ""

# Compare with expected output if available
echo "Step 4: Comparing with expected output..."
EXPECTED="$SCRIPT_DIR/expected/expected_output.csv"
if [ -f "$EXPECTED" ]; then
    # TODO: Add comparison logic
    echo "✅ Comparison complete"
else
    echo "⚠️  Expected output file not found"
fi
echo ""

echo "========================================="
echo "Test Complete"
echo "========================================="
```

Make the script executable:
```bash
chmod +x test/<tool-name>/test_<tool_name>.sh
```

### Step 4: Create Tool-Specific README

Create `test/<tool-name>/README.md`:

```markdown
# <tool-name> Tool Tests

This directory contains all tests and validation tooling for the `<tool-name>.cwl` tool.

## Running Tests

```bash
cd test/<tool-name>
./test_<tool_name>.sh
```

## Test Inputs

Describe the test inputs used and their sources.

## Expected Outputs

Describe the expected outputs and validation criteria.

## Test Validation

The test script validates the CWL tool, runs it, and compares outputs.
```

### Step 5: Test Your New Test

```bash
cd test/<tool-name>
./test_<tool_name>.sh
```

The `test_harness.sh` script automatically discovers and runs all tool tests - no manual updates needed!

## Naming Conventions

- **Directory name**: Use kebab-case matching the CWL tool name
  - `make-xlsx/` for `make-xlsx.cwl`
  - `tidal-correction-fetch/` for `tidal-correction-fetch.cwl`

- **Test files**: Use snake_case
  - `test_make_xlsx.yml`, `test_make_xlsx.sh`
  - `test_tidal_correction_fetch.yml`, `test_tidal_correction_fetch.sh`

- **Test script variable**: Use kebab-case for `TOOL_NAME` (matches directory name)
  - The script automatically converts to snake_case for filenames

## Test Workflow

1. **Development Phase**:
   - Create/update CWL tool definitions
   - Validate with `validate_cwl.py`
   - Test individual tools

2. **Integration Phase**:
   - Run full CWL workflow
   - Compare outputs with `compare_outputs.py`
   - Validate against expected results

3. **Validation Phase**:
   - Run full test harness
   - Verify functional equivalence
   - Document any differences

## Expected Test Results

- **CWL Validation**: All `.cwl` files should validate without errors
- **Simple Test**: Should import CoastSat modules successfully
- **Docker Image**: Should import all required dependencies
- **Output Comparison**: CWL outputs should match minimal implementation (within tolerance)

## Directory Organization Principles

1. **Isolation** - Tool tests don't interfere with each other
2. **Organization** - All tool-specific tests are together
3. **Scalability** - Easy to add new tool tests
4. **Maintainability** - Easy to find and update tool tests
5. **Documentation** - Each tool has its own README

## Notes

- **All inputs, expected outputs, and outputs** are in tool-specific subdirectories, not at the top level
- Tool outputs are saved to `test/<tool-name>/outputs/` for each tool
- Workflow outputs will be saved to `test/workflows/outputs/` when workflows are created
- Outputs are cleaned up by individual tool test scripts and `cleanup.sh`
- Hash-named output files (like `36abc4b...`) are automatically ignored by git and cleaned up
- Tolerance for floating-point comparisons: 1e-6 (configurable in `compare_outputs.py`)
- GeoJSON comparisons require `geopandas` library

## Examples

See `make-xlsx/test_make_xlsx.sh` for a working example of a complete tool test.
