# tidal-correction-fetch Tool Tests

This directory contains all tests and validation tooling for the `tidal-correction-fetch.cwl` tool.

## Tool Overview

The `tidal-correction-fetch.cwl` tool fetches tide data from the NIWA Tide API for a single site based on dates present in a transect time series CSV file.

## Directory Structure

```
tidal-correction-fetch/
├── README.md                          # This file
├── test_tidal_correction_fetch.yml    # Test input file for CWL tool
├── test_tidal_correction_fetch.sh     # Test script (run tests)
├── inputs/                            # Tool-specific inputs (optional)
├── expected/                          # Tool-specific expected outputs (optional)
└── outputs/                           # Generated output files (gitignored)
```

## Running Tests

From the project root:

```bash
cd CoastSat-CWL
export NIWA_TIDE_API_KEY=your_api_key  # Required for tests
./test/tidal-correction-fetch/test_tidal_correction_fetch.sh
```

Or from the test directory:

```bash
cd test/tidal-correction-fetch
export NIWA_TIDE_API_KEY=your_api_key  # Required for tests
./test_tidal_correction_fetch.sh
```

## Test Inputs

The test uses real data from `CoastSat-minimal/data/nzd0001/`:
- `polygons.geojson` - Polygon definitions with site centroids
- `transect_time_series.csv` - Time series data containing dates
- Site ID: `nzd0001`
- NIWA Tide API key: Must be set in environment variable `NIWA_TIDE_API_KEY`

## Expected Outputs

The tool should generate `nzd0001_tides.csv` with:
- `dates` column: Date/time stamps from the transect time series
- `tide` column: Tide values in meters (MSL datum)

**Note:** This tool makes actual API calls to the NIWA Tide API. Rate limiting may apply, and tests may take several minutes depending on the number of dates.

## Test Validation

The test script:
1. ✅ Validates the CWL tool definition
2. ✅ Runs the tool with test inputs (requires valid API key)
3. ✅ Verifies output file creation and content
4. ✅ Checks CSV structure (dates, tide columns)
5. ✅ Compares with expected output if available

## Special Considerations

- **API Key Required**: Tests require a valid `NIWA_TIDE_API_KEY` environment variable
- **Rate Limiting**: NIWA API may rate limit requests (tool includes retry logic)
- **API Timing**: Output values may differ slightly from expected due to API data updates
- **Execution Time**: Fetching tides for many dates can take several minutes

## Adding Expected Outputs

To add expected outputs for comparison:

```bash
# Copy from CoastSat-minimal output
cp ../../../CoastSat-minimal/data/nzd0001/tides.csv expected/nzd0001_tides.csv
```

Or generate expected outputs using the original Python script and place them in `expected/`.

