# Tests Directory

This directory contains validation and testing tools for the CoastSat-CWL workflow.

## Test Scripts

### Validation Tools

- **`compare_with_original.py`** - Main comparison tool that compares outputs from the new minimal workflow against the original CoastSat workflow. Performs detailed comparisons of CSV, GeoJSON, and Excel files with tolerance-based numeric checks.
  ```bash
  python tests/compare_with_original.py --sites nzd0001
  ```

- **`validate_downstream.py`** - Validates only the downstream processing steps (tidal correction, slope estimation, linear models, Excel generation) by using the original `transect_time_series.csv`. This is faster than full workflow validation.
  ```bash
  python tests/validate_downstream.py --sites nzd0001
  ```

- **`validate_outputs.py`** - Simple validation that checks if all expected output files exist and are non-empty. Does not compare with original data.
  ```bash
  python tests/validate_outputs.py
  ```

### Workflow Runners

- **`run_full_workflow.py`** - Runs the complete workflow with validation checks. Uses test mode configuration from `.env` and validates outputs after completion.
  ```bash
  python tests/run_full_workflow.py
  ```

- **`run_workflow.py`** - Simple workflow runner that executes the workflow and then validates outputs. Less comprehensive than `run_full_workflow.py`.
  ```bash
  python tests/run_workflow.py
  ```

### Helper Tools

- **`extract_original_config.py`** - Extracts configuration (date range, satellites, row count) from the original CoastSat data files. Used to set up validation runs that match the original data exactly.
  ```bash
  python tests/extract_original_config.py nzd0001
  ```

- **`diagnose_validation_issues.py`** - Diagnostic tool for analyzing differences between original and new data. Helps understand date range differences and data accumulation patterns.

### Shell Scripts

- **`validate_nzd0001.sh`** - Automated validation script for `nzd0001` site. Extracts configuration, sets up environment, runs workflow, and compares results.
  ```bash
  bash tests/validate_nzd0001.sh
  ```

- **`validate_against_original.sh`** - General validation script for comparing against original CoastSat data.

- **`run_original_workflow.sh`** - Runs the original CoastSat workflow (located in `CoastSat/`) for comparison purposes.

## Validation Workflow

### Quick Validation (Downstream Only)

For fast iteration when testing downstream processing logic:

```bash
python tests/validate_downstream.py --sites nzd0001
```

This:
1. Copies the original `transect_time_series.csv` 
2. Runs downstream steps (tides, slopes, correction, models, Excel)
3. Compares results with original data

### Full Validation

For complete validation including data download and processing:

```bash
# Set up test configuration
export TEST_MODE=true
export TEST_START_DATE=2024-06-01
export TEST_END_DATE=2024-06-15
export TEST_SITES=nzd0001
export TEST_SATELLITES=L8,L9

# Run full workflow with validation
python tests/run_full_workflow.py
```

Or use the automated script:

```bash
bash tests/validate_nzd0001.sh
```

## Expected Outputs

For each site (e.g., `nzd0001`), the workflow should produce:

- `data/{site_id}/transect_time_series.csv` - Raw transect intersections
- `data/{site_id}/tides.csv` - Tide data from NIWA API
- `data/{site_id}/transect_time_series_tidally_corrected.csv` - Tidally corrected data
- `data/{site_id}/{site_id}.xlsx` - Excel summary file
- `inputs/transects_extended.geojson` - Updated with beach slopes and trend statistics

## Comparison Tolerance

The comparison tools use a default tolerance of `1e-6` for numeric comparisons. Differences may occur due to:
- Library version differences
- Floating-point precision
- Minor differences in the `despike` function behavior (documented as expected)
- Different date ranges (when comparing test data with full historical data)

## Notes

- Validation requires the original CoastSat data in `CoastSat/data/` and `CoastSat/transects_extended.geojson`
- Test mode should be enabled for validation to avoid downloading excessive data
- Some differences between original and new outputs are expected and documented (see main README)

