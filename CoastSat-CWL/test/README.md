# Test Directory

This directory contains test utilities and validation scripts for the CoastSat-CWL workflow.

## Test Files

- **`test_simple.cwl`** - Simple CWL tool for verifying Docker image and CWL environment setup
- **`validate_cwl.py`** - Validates CWL tool and workflow files for syntax errors
- **`compare_outputs.py`** - Compares CWL workflow outputs with CoastSat-minimal outputs
- **`run_cwl_workflow.py`** - Executes CWL workflows and collects outputs
- **`test_harness.sh`** - Comprehensive test harness for environment and tool validation
- **`cleanup.sh`** - Cleanup script to remove test outputs and temporary files

## Test Data Directories

- **`inputs/`** - Test input data for CWL workflows (GeoJSON files, configuration files)
- **`expected/`** - Expected outputs from CoastSat-minimal for comparison
- **`outputs/`** - All test outputs (gitignored)
  - **`outputs/cwl/`** - Outputs from CWL workflow execution (for comparison)
  - **`outputs/temp/`** - Temporary test outputs (cleaned up after tests)

## Usage

### Validate CWL Files

```bash
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

### Run Simple CWL Test

```bash
cd CoastSat-CWL
cwltool --outdir test/outputs/temp test/test_simple.cwl
```

Tests that the Docker image and CWL environment work correctly. Outputs are organized in `test/outputs/temp/`.

### Compare Outputs

After running a CWL workflow:

```bash
python3 test/compare_outputs.py
```

Compares CWL outputs in `test/outputs/cwl/` with CoastSat-minimal outputs.

### Run CWL Workflow

```bash
python3 test/run_cwl_workflow.py workflows/coastsat-workflow.cwl examples/workflow-input.yml
```

Runs a CWL workflow and saves outputs to `test/outputs/cwl/` for comparison.

### Cleanup Test Outputs

```bash
cd CoastSat-CWL
./test/cleanup.sh
```

Removes temporary test outputs and hash-named files while preserving directory structure. Use this to clean up after test runs.

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

## Directory Organization

The test directory is organized to prevent clutter:

- **All test outputs** go to `outputs/` directory (gitignored)
- **Temporary outputs** go to `outputs/temp/` (cleaned up after tests)
- **CWL workflow outputs** go to `outputs/cwl/` (for comparison with minimal implementation)
- **Hash-named files** from cwltool (stdout captures) are automatically cleaned up

## Notes

- Test outputs are saved to `test/outputs/cwl/` for comparison
- Temporary outputs are cleaned up by `test_harness.sh` and `cleanup.sh`
- Hash-named output files (like `36abc4b...`) are automatically ignored by git and cleaned up
- Tolerance for floating-point comparisons: 1e-6 (configurable in `compare_outputs.py`)
- GeoJSON comparisons require `geopandas` library
- Full workflow tests require test input data in `test/inputs/`

