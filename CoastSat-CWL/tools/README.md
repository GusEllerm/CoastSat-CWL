# CWL Tools

This directory contains CWL tool definitions for the CoastSat workflow.

## Directory Structure

Each tool has its own subdirectory containing the CWL tool definition and Python wrapper script:

```
tools/
├── README.md                 # This file
├── make-xlsx/               # Excel report generation tool
│   ├── make-xlsx.cwl        # CWL tool definition
│   └── make_xlsx_wrapper.py # Python wrapper script
├── tidal-correction-fetch/  # Tide data fetching tool
│   ├── tidal-correction-fetch.cwl
│   └── tidal_correction_fetch_wrapper.py
└── <tool-name>/             # Future tools follow this pattern
    ├── <tool-name>.cwl
    └── <tool-name>_wrapper.py
```

## Tools

### make-xlsx.cwl

Creates Excel reports from CoastSat outputs for a single site.

**Inputs:**
- `transects_extended`: GeoJSON file with transect definitions
- `transect_time_series_tidally_corrected`: CSV with tidally corrected time series
- `tides`: CSV with tide data
- `site_id`: Site ID (e.g., "nzd0001")

**Outputs:**
- `excel_file`: Excel file (`{site_id}.xlsx`) with multiple sheets:
  - Intersects: Transect intersection data
  - Tides: Tide data
  - Transects: Transect geometry and metadata
  - Intersect points: Computed geographic points

**Dependencies:**
- Uses Docker image: `coastsat-cwl:latest`
- Requires Python wrapper script: `make_xlsx_wrapper.py`

**Testing:**
```bash
cd CoastSat-CWL
./test/make-xlsx/test_make_xlsx.sh
```

**Status:** ✅ Complete and tested

### tidal-correction-fetch.cwl

Fetches tide data from NIWA API for a single site.

**Inputs:**
- `polygons`: GeoJSON file with polygon definitions
- `transect_time_series`: CSV with transect time series data (contains dates)
- `site_id`: Site ID (e.g., "nzd0001")
- `niwa_api_key`: NIWA Tide API key (optional if `NIWA_TIDE_API_KEY` env var is set)

**Outputs:**
- `tides_csv`: CSV file (`{site_id}_tides.csv`) with tide data:
  - `dates`: Date/time stamps
  - `tide`: Tide values in meters (MSL datum)

**Dependencies:**
- Uses Docker image: `coastsat-cwl:latest`
- Requires Python wrapper script: `tidal_correction_fetch_wrapper.py`
- Requires valid NIWA Tide API key (via input or environment variable)
- Requires network access (configured via `NetworkAccess` requirement) for API calls

**Testing:**
```bash
cd CoastSat-CWL
export NIWA_TIDE_API_KEY=your_api_key  # Required for tests
./test/tidal-correction-fetch/test_tidal_correction_fetch.sh
```

**Status:** ✅ Complete and tested (requires API key for execution)

### tidal-correction-apply.cwl

Applies tidal corrections to transect time series using beach slopes.

**Inputs:**
- `transect_time_series`: CSV with raw transect time series data
- `tides`: CSV with tide data for the site
- `transects_extended`: GeoJSON with transect definitions (must include `beach_slope` field)
- `site_id`: Site ID (e.g., "nzd0001")

**Outputs:**
- `tidally_corrected_csv`: CSV file (`{site_id}_transect_time_series_tidally_corrected.csv`) with tidally corrected data:
  - `dates`: Date/time stamps
  - Transect columns: Tidally corrected chainage values
  - `satname` (if present): Satellite name

**Dependencies:**
- Uses Docker image: `coastsat-cwl:latest`
- Requires Python wrapper script: `tidal_correction_apply_wrapper.py`
- Requires `beach_slope` values in `transects_extended.geojson` (from slope estimation step)

**Testing:**
```bash
cd CoastSat-CWL
./test/tidal-correction-apply/test_tidal_correction_apply.sh
```

**Status:** ✅ Complete and tested

### slope-estimation.cwl

Estimates beach slopes for transects using spectral analysis.

**Inputs:**
- `transect_time_series`: CSV with transect time series data
- `tides`: CSV with tide data for the site
- `transects_extended`: GeoJSON with transect definitions
- `sds_slope_module`: Python module file (`SDS_slope.py`) - required dependency
- `site_id`: Site ID (e.g., "nzd0001")

**Outputs:**
- `updated_transects`: GeoJSON file (`{site_id}_transects_updated.geojson`) with updated transects:
  - All transects for the site
  - `beach_slope` column populated with estimated slopes
  - `cil` and `ciu` columns with confidence intervals (if slopes were estimated)

**Dependencies:**
- Uses Docker image: `coastsat-cwl:latest`
- Requires Python wrapper script: `slope_estimation_wrapper.py`
- Requires `SDS_slope.py` module (staged via InitialWorkDirRequirement)
- Performs computationally intensive spectral analysis (may take several minutes)

**Testing:**
```bash
cd CoastSat-CWL
./test/slope-estimation/test_slope_estimation.sh
```

**Note:** Execution time varies based on number of transects and data points (may take several minutes).

**Status:** ✅ Complete and tested

### linear-models.cwl

Calculates linear trends for tidally corrected transect time series data.

**Inputs:**
- `transect_time_series`: CSV with tidally corrected transect time series data (`transect_time_series_tidally_corrected.csv`)
- `transects_extended`: GeoJSON with transect definitions
- `site_id`: Site ID (e.g., "nzd0001")

**Outputs:**
- `updated_transects`: GeoJSON file (`{site_id}_transects_with_trends.geojson`) with updated transects:
  - All transects for the site
  - `trend`: Linear trend (meters/year) - slope of linear regression
  - `intercept`: Intercept of linear regression
  - `n_points`: Total number of points for the transect
  - `n_points_nonan`: Number of non-NaN points used in regression
  - `r2_score`: R-squared score (coefficient of determination)
  - `mae`: Mean absolute error
  - `mse`: Mean squared error
  - `rmse`: Root mean squared error

**Dependencies:**
- Uses Docker image: `coastsat-cwl:latest`
- Requires Python wrapper script: `linear_models_wrapper.py`
- Uses sklearn LinearRegression for trend calculation
- Requires tidally corrected transect time series data

**Testing:**
```bash
cd CoastSat-CWL
./test/linear-models/test_linear_models.sh
```

**Status:** ✅ Complete and tested

### batch-process-nz.cwl

Downloads satellite imagery from Google Earth Engine and extracts shorelines for a single NZ site.

**Inputs:**
- `site_id`: Site ID (e.g., "nzd0001")
- `polygons`: GeoJSON file with polygon definitions
- `shorelines`: GeoJSON file with reference shoreline definitions
- `transects_extended`: GeoJSON file with transect definitions
- `output_dir`: Output directory (will create `data/{site_id}/` subdirectory)
- `start_date`: Start date for image download (YYYY-MM-DD, default: 1984-01-01)
- `end_date`: End date for image download (YYYY-MM-DD, default: 2030-12-30)
- `sat_list`: Satellite list (e.g., ["L8", "L9"], default: ["L5", "L7", "L8", "L9"])
- `gee_service_account`: Google Earth Engine service account email (optional if env var set)
- `gee_private_key`: Path to GEE private key JSON file (optional if env var set)

**Outputs:**
- `transect_time_series`: CSV file (`data/{site_id}/transect_time_series.csv`) with:
  - `dates`: Date/time stamps of satellite images
  - `satname`: Satellite name (e.g., L8, L9)
  - Transect columns: Chainage values for each transect at each date

**Dependencies:**
- Uses Docker image: `coastsat-cwl:latest`
- Requires Python wrapper script: `batch_process_nz_wrapper.py`
- Requires network access for Google Earth Engine API
- Requires GEE authentication (service account credentials)
- Downloads satellite imagery from Google Earth Engine
- Performs shoreline extraction and transect intersection computation

**Testing:**
```bash
cd CoastSat-CWL
export GEE_SERVICE_ACCOUNT=your_service_account
export GEE_PRIVATE_KEY_PATH=/path/to/.private-key.json
./test/batch-process-nz/test_batch_process_nz.sh
```

**Note:** 
- Execution time varies significantly (minutes to hours) depending on date range and number of images
- Requires valid Google Earth Engine service account credentials
- Downloads satellite imagery which can produce large output files
- Test script will skip execution if credentials are not available (but will still validate CWL)

**Status:** ✅ Complete and tested (requires GEE credentials for execution)

### batch-process-sar.cwl

Downloads satellite imagery from Google Earth Engine and extracts shorelines for a single SAR site.

**Inputs:**
- `site_id`: Site ID (e.g., "sar0001")
- `polygons`: GeoJSON file with polygon definitions
- `shorelines`: GeoJSON file with reference shoreline definitions
- `transects_extended`: GeoJSON file with transect definitions
- `output_dir`: Output directory (will create `data/{site_id}/` subdirectory)
- `start_date`: Start date for image download (YYYY-MM-DD, default: 1900-01-01)
- `end_date`: End date for image download (YYYY-MM-DD, default: 2030-12-30)
- `sat_list`: Satellite list (e.g., ["L8", "L9"], default: ["L5", "L7", "L8", "L9"])
- `gee_service_account`: Google Earth Engine service account email (optional if env var set)
- `gee_private_key`: Path to GEE private key JSON file (optional if env var set)

**Outputs:**
- `transect_time_series`: CSV file (`data/{site_id}/transect_time_series.csv`) with:
  - `dates`: Date/time stamps of satellite images
  - `satname`: Satellite name (e.g., L8, L9)
  - Transect columns: Chainage values for each transect at each date

**Dependencies:**
- Uses Docker image: `coastsat-cwl:latest`
- Requires Python wrapper script: `batch_process_sar_wrapper.py`
- Requires network access for Google Earth Engine API
- Requires GEE authentication (service account credentials)
- Downloads satellite imagery from Google Earth Engine
- Performs shoreline extraction and transect intersection computation

**Differences from batch-process-nz:**
- CRS: EPSG:3003 (NZ uses EPSG:2193)
- Site prefix: "sar" (NZ uses "nzd")
- Default start date: "1900-01-01" (NZ uses "1984-01-01")
- Reference shoreline: NOT flipped (NZ flips shorelines)
- Georeferencing threshold: 15m (NZ uses 10m)

**Testing:**
```bash
cd CoastSat-CWL
export GEE_SERVICE_ACCOUNT=your_service_account
export GEE_PRIVATE_KEY_PATH=/path/to/.private-key.json
./test/batch-process-sar/test_batch_process_sar.sh
```

**Note:** 
- Execution time varies significantly (minutes to hours) depending on date range and number of images
- Requires valid Google Earth Engine service account credentials
- Downloads satellite imagery which can produce large output files
- Test script will skip execution if credentials are not available (but will still validate CWL)

**Status:** ✅ Complete and tested (requires GEE credentials for execution)

## Testing

Each tool should have:
1. A CWL tool definition (`.cwl` file)
2. A Python wrapper script (if needed)
3. A test input file (in `test/` directory)
4. A test script (in `test/` directory)

Test scripts should:
- Validate the CWL tool
- Run the tool with test inputs
- Verify outputs
- Compare with expected outputs if available
