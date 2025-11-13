# slope-estimation Tool Tests

This directory contains all tests and validation tooling for the `slope-estimation.cwl` tool.

## Tool Overview

The `slope-estimation.cwl` tool estimates beach slopes for transects using spectral analysis. It processes a single site and outputs updated transects for that site with `beach_slope` values populated.

## Directory Structure

```
slope-estimation/
├── README.md                           # This file
├── test_slope_estimation.yml          # Test input file for CWL tool
├── test_slope_estimation.sh           # Test script (run tests)
├── inputs/                             # Tool-specific inputs (optional)
├── expected/                           # Tool-specific expected outputs (optional)
└── outputs/                            # Generated output files (gitignored)
```

## Running Tests

From the project root:

```bash
cd CoastSat-CWL
./test/slope-estimation/test_slope_estimation.sh
```

Or from the test directory:

```bash
cd test/slope-estimation
./test_slope_estimation.sh
```

**Note:** This tool performs computationally intensive spectral analysis and may take several minutes to execute.

## Test Inputs

The test uses real data from `CoastSat-minimal/data/nzd0001/`:
- `transect_time_series.csv` - Transect intersection time series data
- `tides.csv` - Tide data for the site (from `tidal-correction-fetch` step)
- `transects_extended.geojson` - Transect definitions
- `SDS_slope.py` - Slope estimation module (required dependency)
- Site ID: `nzd0001`

## Expected Outputs

The tool should generate `nzd0001_transects_updated.geojson` with:
- All transects for the site
- `beach_slope` column populated with estimated slopes
- `cil` and `ciu` columns with confidence intervals (if slopes were estimated)
- Same geometry and other attributes as input transects

## Test Validation

The test script:
1. ✅ Validates the CWL tool definition
2. ✅ Runs the tool with test inputs
3. ✅ Verifies output file creation and content
4. ✅ Checks GeoJSON structure (valid GeoJSON, beach_slope column present)
5. ✅ Counts transects with beach_slope values
6. ✅ Compares with expected output if available

## Special Considerations

- **Computationally Intensive**: This tool performs spectral analysis and may take several minutes for sites with many transects or data points
- **Requires SDS_slope Module**: The tool requires the `SDS_slope.py` module to be provided as an input (automatically staged via InitialWorkDirRequirement)
- **Slope Estimation**: Only estimates slopes for transects that don't already have `beach_slope` values
- **Per-Site Processing**: Processes one site at a time; outputs transects for that site only
- **Workflow Integration**: In a workflow, multiple per-site outputs will need to be aggregated into a single `transects_extended.geojson` file
- **Processing Order**: This tool should be run after:
  1. Batch processing (generates `transect_time_series.csv`)
  2. Tidal correction fetch (generates `tides.csv`)

## Adding Expected Outputs

To add expected outputs for comparison:

```bash
# Note: The tool outputs transects for a single site only
# For comparison, extract transects for the site from the full transects_extended.geojson
python3 -c "
import geopandas as gpd
gdf = gpd.read_file('../../../CoastSat-minimal/inputs/transects_extended.geojson')
gdf[gdf.site_id == 'nzd0001'].to_file('expected/nzd0001_transects_updated.geojson')
"
```

