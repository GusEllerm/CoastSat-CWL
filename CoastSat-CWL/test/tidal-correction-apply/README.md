# tidal-correction-apply Tool Tests

This directory contains all tests and validation tooling for the `tidal-correction-apply.cwl` tool.

## Tool Overview

The `tidal-correction-apply.cwl` tool applies tidal corrections to transect time series data using beach slopes from the transects GeoJSON file.

## Directory Structure

```
tidal-correction-apply/
├── README.md                               # This file
├── test_tidal_correction_apply.yml        # Test input file for CWL tool
├── test_tidal_correction_apply.sh         # Test script (run tests)
├── inputs/                                 # Tool-specific inputs (optional)
├── expected/                               # Tool-specific expected outputs (optional)
└── outputs/                                # Generated output files (gitignored)
```

## Running Tests

From the project root:

```bash
cd CoastSat-CWL
./test/tidal-correction-apply/test_tidal_correction_apply.sh
```

Or from the test directory:

```bash
cd test/tidal-correction-apply
./test_tidal_correction_apply.sh
```

## Test Inputs

The test uses real data from `CoastSat-minimal/data/nzd0001/`:
- `transect_time_series.csv` - Raw transect intersection time series data
- `tides.csv` - Tide data for the site (from `tidal-correction-fetch` step)
- `transects_extended.geojson` - Transect definitions with beach slopes (must have `beach_slope` field populated)
- Site ID: `nzd0001`

## Expected Outputs

The tool should generate `nzd0001_transect_time_series_tidally_corrected.csv` with:
- `dates` column: Date/time stamps
- Transect columns: Tidally corrected chainage values for each transect
- `satname` column (if present in input): Satellite name

The output should match the result from `CoastSat-minimal/data/nzd0001/transect_time_series_tidally_corrected.csv`.

## Test Validation

The test script:
1. ✅ Validates the CWL tool definition
2. ✅ Runs the tool with test inputs
3. ✅ Verifies output file creation and content
4. ✅ Checks CSV structure (dates, transect columns)
5. ✅ Compares with expected output if available

## Special Considerations

- **Requires Beach Slopes**: The `transects_extended.geojson` file must have `beach_slope` values populated (from slope estimation step)
- **Despike Behavior**: The tool applies an outlier removal (despike) algorithm which may result in slightly different outputs compared to inputs due to union of dates across columns
- **Processing Order**: This tool should be run after:
  1. Batch processing (generates `transect_time_series.csv`)
  2. Tidal correction fetch (generates `tides.csv`)
  3. Slope estimation (populates `beach_slope` in `transects_extended.geojson`)

## Adding Expected Outputs

To add expected outputs for comparison:

```bash
# Copy from CoastSat-minimal output
cp ../../../CoastSat-minimal/data/nzd0001/transect_time_series_tidally_corrected.csv expected/nzd0001_transect_time_series_tidally_corrected.csv
```

