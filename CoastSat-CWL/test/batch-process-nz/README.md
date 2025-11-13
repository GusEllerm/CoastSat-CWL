# batch-process-nz Tool Tests

This directory contains all tests and validation tooling for the `batch-process-nz.cwl` tool.

## Tool Overview

The `batch-process-nz.cwl` tool processes a single NZ site by:
1. Downloading satellite imagery from Google Earth Engine
2. Extracting shorelines from the imagery
3. Computing intersections with transects
4. Generating transect time series CSV file

## Directory Structure

```
batch-process-nz/
├── README.md                           # This file
├── test_batch_process_nz.yml           # Test input file for CWL tool
├── test_batch_process_nz.sh            # Test script (run tests)
├── inputs/                              # Tool-specific inputs (optional)
├── expected/                            # Tool-specific expected outputs (optional)
└── outputs/                             # Generated output files (gitignored)
```

## Running Tests

From the project root:

```bash
cd CoastSat-CWL
./test/batch-process-nz/test_batch_process_nz.sh
```

Or from the test directory:

```bash
cd test/batch-process-nz
./test_batch_process_nz.sh
```

**⚠️ Important**: This tool requires Google Earth Engine authentication. You must set:
- `GEE_SERVICE_ACCOUNT`: Google Earth Engine service account email
- `GEE_PRIVATE_KEY_PATH`: Path to GEE private key JSON file

Or provide them via `.env` file in the project root.

## Test Inputs

The test uses real data from `CoastSat-minimal/inputs/`:
- `polygons.geojson` - Polygon definitions for NZ sites
- `shorelines.geojson` - Reference shoreline definitions
- `transects_extended.geojson` - Transect definitions
- Site ID: `nzd0001`
- Date range: 2024-01-01 to 2024-12-31 (configurable in test script)
- Satellites: L8, L9 (configurable in test script)

## Expected Outputs

The tool should generate `data/{site_id}/transect_time_series.csv` with:
- `dates`: Date/time stamps of satellite images
- `satname`: Satellite name (e.g., L8, L9)
- Transect columns: Chainage values for each transect at each date
- Additional metadata as needed

## Test Validation

The test script:
1. ✅ Validates the CWL tool definition
2. ✅ Checks for GEE credentials
3. ✅ Runs the tool with test inputs (if credentials available)
4. ✅ Verifies output file creation and content
5. ✅ Checks CSV structure (dates, transect columns)
6. ✅ Compares with expected output if available

## Special Considerations

- **Google Earth Engine Authentication Required**: This tool requires valid GEE service account credentials
- **Network Access**: Requires network connectivity to access Google Earth Engine
- **Long Execution Time**: Downloading and processing satellite imagery can take several minutes to hours depending on:
  - Date range size
  - Number of available images
  - Cloud coverage
  - Network speed
- **Large Output Files**: Satellite imagery downloads can produce large output files
- **Per-Site Processing**: Processes one site at a time (designed for CWL scatter)
- **Incremental Processing**: If output file exists, tool continues from last processed date
- **Date Range**: Default is 1984-01-01 to 2030-12-30, but can be limited for testing

## GEE Credential Setup

To run this tool, you need:

1. **Google Earth Engine Service Account**:
   - Create a service account in Google Cloud Console
   - Enable Earth Engine API for the project
   - Create and download a private key JSON file

2. **Set Credentials**:
   ```bash
   export GEE_SERVICE_ACCOUNT="your-service-account@project.iam.gserviceaccount.com"
   export GEE_PRIVATE_KEY_PATH="/path/to/.private-key.json"
   ```

   Or add to `.env` file:
   ```
   GEE_SERVICE_ACCOUNT=your-service-account@project.iam.gserviceaccount.com
   GEE_PRIVATE_KEY_PATH=/path/to/.private-key.json
   ```

## Adding Expected Outputs

To add expected outputs for comparison:

```bash
# Copy from CoastSat-minimal output
cp ../../../CoastSat-minimal/data/nzd0001/transect_time_series.csv expected/data/nzd0001/transect_time_series.csv
```

Note: Outputs may vary slightly due to processing differences or date ranges, so detailed comparison may show differences.

