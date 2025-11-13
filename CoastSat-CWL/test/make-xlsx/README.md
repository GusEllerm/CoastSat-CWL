# make-xlsx Tool Tests

This directory contains all tests and validation tooling for the `make-xlsx.cwl` tool.

## Directory Structure

```
make-xlsx/
├── README.md                  # This file
├── test_make_xlsx.yml        # Test input file for CWL tool
├── test_make_xlsx.sh         # Test script (run tests)
├── inputs/                   # Test input files (if needed)
├── expected/                 # Expected output files for comparison
└── outputs/                  # Generated output files (gitignored)
```

## Running Tests

From the `test/make-xlsx/` directory:

```bash
cd test/make-xlsx
./test_make_xlsx.sh
```

Or from the project root:

```bash
cd CoastSat-CWL
./test/make-xlsx/test_make_xlsx.sh
```

## Test Inputs

The test uses real data from `CoastSat-minimal/data/nzd0001/`:
- `transects_extended.geojson` - Transect definitions
- `transect_time_series_tidally_corrected.csv` - Time series data
- `tides.csv` - Tide data
- Site ID: `nzd0001`

## Expected Outputs

The tool should generate `nzd0001.xlsx` with 4 sheets:
1. **Intersects** - Transect intersection data
2. **Tides** - Tide data
3. **Transects** - Transect geometry and metadata
4. **Intersect points** - Computed geographic points

If an expected output file is available in `expected/`, the test script will compare sizes.

## Test Validation

The test script:
1. ✅ Validates the CWL tool definition
2. ✅ Runs the tool with test inputs
3. ✅ Verifies output file creation and content
4. ✅ Compares with expected output (if available)

## Adding Expected Outputs

To add expected outputs for comparison:

```bash
# Copy from CoastSat-minimal output
cp ../../../CoastSat-minimal/data/nzd0001/nzd0001.xlsx expected/
```

Or generate expected outputs using the original Python script and place them in `expected/`.

