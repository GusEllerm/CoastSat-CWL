# linear-models Tool Tests

This directory contains all tests and validation tooling for the `linear-models.cwl` tool.

## Tool Overview

The `linear-models.cwl` tool calculates linear trends for tidally corrected transect time series data using sklearn LinearRegression. It processes a single site and outputs updated transects for that site with trend statistics.

## Directory Structure

```
linear-models/
├── README.md                           # This file
├── test_linear_models.yml              # Test input file for CWL tool
├── test_linear_models.sh               # Test script (run tests)
├── inputs/                              # Tool-specific inputs (optional)
├── expected/                            # Tool-specific expected outputs (optional)
└── outputs/                             # Generated output files (gitignored)
```

## Running Tests

From the project root:

```bash
cd CoastSat-CWL
./test/linear-models/test_linear_models.sh
```

Or from the test directory:

```bash
cd test/linear-models
./test_linear_models.sh
```

## Test Inputs

The test uses real data from `CoastSat-minimal/data/nzd0001/`:
- `transect_time_series_tidally_corrected.csv` - Tidally corrected transect time series data
- `transects_extended.geojson` - Transect definitions
- Site ID: `nzd0001`

## Expected Outputs

The tool should generate `nzd0001_transects_with_trends.geojson` with:
- All transects for the site
- `trend`: Linear trend (meters/year) - slope of linear regression
- `intercept`: Intercept of linear regression
- `n_points`: Total number of points for the transect
- `n_points_nonan`: Number of non-NaN points used in regression
- `r2_score`: R-squared score (coefficient of determination)
- `mae`: Mean absolute error
- `mse`: Mean squared error
- `rmse`: Root mean squared error
- Same geometry and other attributes as input transects

## Test Validation

The test script:
1. ✅ Validates the CWL tool definition
2. ✅ Runs the tool with test inputs
3. ✅ Verifies output file creation and content
4. ✅ Checks GeoJSON structure (valid GeoJSON, trend statistics columns present)
5. ✅ Counts transects with trend values
6. ✅ Compares with expected output if available

## Special Considerations

- **Requires Tidally Corrected Data**: This tool requires tidally corrected transect time series data (from `tidal-correction-apply` step)
- **Linear Regression**: Uses sklearn LinearRegression to fit trends
- **Time Conversion**: Converts dates to years since first date for regression
- **Per-Site Processing**: Processes one site at a time; outputs transects for that site only
- **Workflow Integration**: In a workflow, multiple per-site outputs will need to be aggregated into a single `transects_extended.geojson` file
- **Processing Order**: This tool should be run after:
  1. Batch processing (generates `transect_time_series.csv`)
  2. Tidal correction fetch (generates `tides.csv`)
  3. Slope estimation (populates `beach_slope` in `transects_extended.geojson`)
  4. Tidal correction apply (generates `transect_time_series_tidally_corrected.csv`)

## Adding Expected Outputs

To add expected outputs for comparison:

```bash
# Note: The tool outputs transects for a single site only
# For comparison, extract transects for the site from the full transects_extended.geojson
python3 -c "
import geopandas as gpd
gdf = gpd.read_file('../../../CoastSat-minimal/inputs/transects_extended.geojson')
gdf[gdf.site_id == 'nzd0001'].to_file('expected/nzd0001_transects_with_trends.geojson')
"
```

