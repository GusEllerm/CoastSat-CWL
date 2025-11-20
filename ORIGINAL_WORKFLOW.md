# CoastSat-Original Workflow Documentation

## Overview

The CoastSat-Original project is an automated shoreline monitoring system that processes satellite imagery from Google Earth Engine (GEE) to track shoreline changes over time. The system runs on a VM (`wave.storm-surge.cloud.edu.au`) and executes monthly via a cron job, incrementally adding new data to its dataset.

## Core Workflow

The workflow is orchestrated by `update.sh`, which executes the following steps:

### 1. Git Pull (`git pull`)
- Pulls the latest changes from the repository to ensure the codebase is up-to-date

### 2. Batch Processing - New Zealand Sites (`./batch_process_NZ.py`)
- Processes all sites with IDs starting with `"nzd"` (New Zealand sites)
- Uses CRS 2193 (New Zealand Transverse Mercator)
- **Incremental Processing**: 
  - Checks if `data/{sitename}/transect_time_series.csv` exists
  - If it exists, reads the maximum date and only processes imagery after that date
  - If it doesn't exist, processes all available imagery from 1984-01-01
- Downloads Landsat imagery (L5, L7, L8, L9) from GEE using a service account
- Extracts shorelines from the imagery
- Computes intersections between shorelines and transects
- Appends new results to `data/{sitename}/transect_time_series.csv`

### 3. Batch Processing - SAR Sites (`./batch_process_sar.py`)
- Processes all sites with IDs starting with `"sar"` (Sardinia sites)
- Uses CRS 3003 (Italian coordinate system)
- Same incremental processing logic as NZ sites
- Same workflow: download → extract → intersect → append

### 4. Tidal Correction - First Pass (`tidal_correction.ipynb`)
- **Applies only to NZ sites** (sites with IDs starting with `"nzd"`)
- Reads `transect_time_series.csv` for each NZ site
- Fetches tide data from the NIWA Tide API for each timestamp
- Saves tide data to `data/{sitename}/tides.csv`
- **Note**: This first pass is needed to fetch tide data before slope estimation
- **SAR sites are skipped**: Sardinia sites do not use tidal correction (no tide data fetched)

### 5. Slope Estimation (`slope_estimation.ipynb`)
- **Applies only to NZ sites** (sites with IDs starting with `"nzd"`)
- Estimates beach slopes for each transect using the tidally-corrected data
- Adds the following properties to `transects_extended.geojson`:
  - `beach_slope`: Estimated beach slope
  - `cil`: Lower confidence interval for slope
  - `ciu`: Upper confidence interval for slope
- **SAR sites are skipped**: Sardinia sites do not have beach slopes calculated (no tidal correction applied)

### 6. Tidal Correction - Second Pass (`tidal_correction.ipynb`)
- **Applies only to NZ sites** (sites with IDs starting with `"nzd"`)
- Re-runs tidal correction, now using the estimated slopes from step 5
- Applies tidal correction to the raw transect intersections
- Saves tidally-corrected data to `data/{sitename}/transect_time_series_tidally_corrected.csv`
- **SAR sites are skipped**: Sardinia sites do not have tidally-corrected data (only raw `transect_time_series.csv` exists)

### 7. Linear Models (`linear_models.ipynb`)
- Calculates linear regression models for each transect
- **For NZ sites**: Uses tidally-corrected time series (`transect_time_series_tidally_corrected.csv`)
- **For SAR sites**: Uses raw time series (`transect_time_series.csv`) since no tidal correction is applied
- Adds the following statistical properties to `transects_extended.geojson`:
  - `trend`: Linear trend (m/year) - positive = accretion, negative = erosion
  - `n_points`: Total number of data points
  - `n_points_nonan`: Number of non-NaN data points
  - `r2_score`: R² score of the linear fit
  - `mae`: Mean Absolute Error
  - `mse`: Mean Squared Error
  - `rmse`: Root Mean Squared Error
  - `intercept`: Y-intercept of the linear model

### 8. Excel Generation (`./make_xlsx.py`)
- **Applies only to NZ sites** (sites with IDs starting with `"nzd"`)
- Creates Excel files (`data/{sitename}/{sitename}.xlsx`) for each NZ site with:
  - **Intersects sheet**: Tidally-corrected transect intersections over time
  - **Tides sheet**: Tide data for each timestamp
  - **Transects sheet**: Transect geometry and metadata
  - **Intersect points sheet**: Geographic coordinates of intersection points
- **SAR sites are skipped**: Sardinia sites do not have Excel files generated (no tide data or tidally-corrected data available)

### 9. Git Commit and Push
- Stages all changes (`git add .`)
- Commits with message "auto update" and bot author
- Pushes to the repository
- Creates a timestamped git tag
- Creates a GitHub release with auto-generated notes

## Key Data Files

### `transects_extended.geojson`
This is the **core output file** that gets iteratively updated with additional measurements. It contains:
- **Geometry**: LineString features representing transects (origin is landward)
- **Properties**:
  - `id`: Unique transect identifier (e.g., "nzd0001-0000")
  - `site_id`: Site identifier (e.g., "nzd0001")
  - `orientation`: Transect orientation angle
  - `along_dist`: Distance along the shoreline
  - `along_dist_norm`: Normalized distance along shoreline
  - `beach_slope`: Beach slope (added by `slope_estimation.ipynb`)
  - `cil`, `ciu`: Confidence intervals for slope (added by `slope_estimation.ipynb`)
  - `trend`: Linear trend in m/year (added by `linear_models.ipynb`)
  - `n_points`, `n_points_nonan`: Data point counts (added by `linear_models.ipynb`)
  - `r2_score`, `mae`, `mse`, `rmse`: Model fit statistics (added by `linear_models.ipynb`)
  - `intercept`: Linear model intercept (added by `linear_models.ipynb`)
  - `ERODIBILITY`: Erodibility classification (currently null)

### `data/{sitename}/transect_time_series.csv`
Time series of raw transect intersections (exists for both NZ and SAR sites):
- `dates`: Timestamp of each observation
- `satname`: Satellite name (L5, L7, L8, L9)
- One column per transect ID with cross-shore distances (chainage)
- **This is the primary data file for SAR sites** (no tidal correction applied)

### `data/{sitename}/transect_time_series_tidally_corrected.csv`
- **NZ sites only**: Same structure as `transect_time_series.csv`, but with tidal corrections applied
- **SAR sites**: This file does not exist for Sardinia sites (no tidal correction applied)

### `data/{sitename}/tides.csv`
- **NZ sites only**: Tide data fetched from NIWA API for each timestamp
- **SAR sites**: This file does not exist for Sardinia sites (no tide data fetched)

## Incremental Data Addition

The system is designed to **incrementally add data** rather than reprocess everything:

1. **Batch Processing Scripts** (`batch_process_NZ.py`, `batch_process_sar.py`):
   - Check the maximum date in existing `transect_time_series.csv`
   - Only download and process imagery after that date
   - Append new results to the CSV (not overwrite)

2. **Analysis Notebooks**:
   - **`slope_estimation.ipynb`** (NZ sites only): Recalculates beach slopes using the **entire** tidally-corrected time series
   - **`linear_models.ipynb`** (all sites): Recalculates trends and statistics using the **entire** time series
     - For NZ sites: Uses tidally-corrected data
     - For SAR sites: Uses raw data (no tidal correction)
   - Updates `transects_extended.geojson` with recalculated values
   - This ensures that as more data accumulates, the statistical models improve

## Simulating the Workflow Transition

To replicate the transition from a previous dataset state to the current state, you would need to:

### Minimal Validation Approach (One NZD Site + One SAR Site)

1. **Identify a previous state**:
   - Checkout a previous git tag/commit that represents an earlier dataset state
   - Note the date range of data in `transect_time_series.csv` for your test sites

2. **Run the workflow incrementally**:
   ```bash
   # Modify batch_process_NZ.py to only process one site
   # Modify batch_process_sar.py to only process one site
   # Or filter the polygons.geojson to only include test sites
   
   ./batch_process_NZ.py  # Will only process new dates
   ./batch_process_sar.py  # Will only process new dates
   
   # Run notebooks (they process all sites, but you can filter)
   jupyter nbconvert --to notebook --execute --inplace tidal_correction.ipynb
   jupyter nbconvert --to notebook --execute --inplace slope_estimation.ipynb
   jupyter nbconvert --to notebook --execute --inplace tidal_correction.ipynb
   jupyter nbconvert --to notebook --execute --inplace linear_models.ipynb
   
   ./make_xlsx.py
   ```

3. **Compare results**:
   - Compare `transect_time_series.csv` - should have new rows appended
   - Compare `transects_extended.geojson` - statistical properties should be updated
   - Verify that new data points match what's in the current repository

### Key Considerations for Simulation

1. **GEE Access**: You need:
   - A Google Earth Engine service account
   - The `.private-key.json` file
   - Proper authentication set up

2. **NIWA Tide API**: You need:
   - API credentials for the NIWA Tide API
   - Network access to fetch tide data

3. **Date Range**: The scripts automatically determine what dates to process based on existing data. To simulate a specific transition:
   - Start from a git tag/commit with a known dataset state
   - Run the workflow
   - The scripts will automatically process only new dates

4. **Reproducibility**: 
   - The workflow should produce identical results if run on the same date range
   - However, GEE imagery availability may vary slightly
   - Tide data should be consistent

5. **Data Volume**: 
   - The full dataset is 1.3TB
   - For validation, you can limit to 1-2 sites to reduce processing time
   - The `.gitignore` excludes heavy imagery files, only tracking CSV results

## Dependencies

- **CoastSat**: Python package for shoreline extraction
- **Google Earth Engine**: For satellite imagery access
- **NIWA Tide API**: For tidal corrections
- **Geopandas**: For geospatial data handling
- **Pandas**: For time series data
- **Jupyter**: For notebook execution

See `requirements.txt` for full dependency list.

## Automation

The workflow runs automatically on the 1st of each month via cron:
```bash
0 0  1   *   *     cd CoastSat && ./update.sh &> update.log
```

This ensures the dataset is continuously updated with new satellite imagery as it becomes available.

