# CoastSat Validation Methodology

## Overview

This document describes the validation methodology used to verify that the CoastSat-Original workflow correctly processes data incrementally. This validation framework will be used to validate a future CWL (Common Workflow Language) refactor of CoastSat, ensuring the refactored implementation produces identical results to the original.

## Purpose

The validation framework serves two primary purposes:

1. **Validate CoastSat-Original**: Verify that the incremental data processing workflow works correctly by simulating the transition from a previous dataset state to the current state.

2. **Validate CWL Refactor**: Once the CoastSat workflow is refactored to CWL, this same validation framework will be used to ensure the CWL implementation produces identical results to CoastSat-Original.

## How CoastSat-Original Works

### Incremental Data Processing

CoastSat-Original processes data **incrementally**, not from scratch:

1. **Each run processes only new data** since the last commit
2. **Data accumulates** - new observations are appended to existing CSV files
3. **Statistics are recalculated** - `transects_extended.geojson` is updated with new statistics based on all accumulated data
4. **Not a full reprocess** - the workflow doesn't start from scratch each time

### Workflow Steps

The `update.sh` script orchestrates the following steps:

1. **Batch Processing (NZ sites)**: `batch_process_NZ.py`
   - Reads existing `transect_time_series.csv` files
   - Finds the maximum date in existing data
   - Sets `min_date = max_date + 1 day`
   - Downloads new satellite images from Google Earth Engine (GEE)
   - Extracts shorelines from new images
   - Appends new data to existing CSV files

2. **Batch Processing (SAR sites)**: `batch_process_sar.py`
   - Same process as NZ sites, but for SAR imagery

3. **Tidal Correction (first pass)**: `tidal_correction.ipynb`
   - Fetches tide data from NIWA API for new dates
   - Applies tidal corrections using existing beach slopes

4. **Slope Estimation**: `slope_estimation.ipynb`
   - Calculates beach slopes from tidally-corrected data
   - Updates `transects_extended.geojson` with slope values

5. **Tidal Correction (second pass)**: `tidal_correction.ipynb`
   - Re-applies tidal corrections using newly calculated slopes
   - Includes despike function to remove outliers

6. **Linear Models**: `linear_models.ipynb`
   - Calculates linear trends, R², RMSE, MAE, MSE for each transect
   - Updates `transects_extended.geojson` with statistics

7. **Excel Generation**: `make_xlsx.py`
   - Generates Excel reports for each NZ site

8. **Git Commit**: Commits and pushes results

## Validation Methodology

### Core Principle

**The validation framework replicates the incremental processing behavior by running the workflow for each commit in sequence, just as the original does.**

### Validation Process

1. **Extract Baseline Data** (from previous commit, e.g., `HEAD~9`)
   - This represents the "starting state" before new data was added

2. **Extract Validation Data** (from current commit, `HEAD`)
   - This represents the "expected final state" after all incremental updates

3. **Run Incremental Workflow**
   - Process each commit incrementally: `HEAD~9 → HEAD~8 → HEAD~7 → ... → HEAD`
   - Each step processes only new data since the previous commit
   - Data accumulates just like in the original workflow

4. **Compare Results**
   - Compare workflow output against validation data
   - Verify that all common dates match exactly
   - Account for dates that exist in validation but not in workflow (due to processing differences)

### Why Incremental Processing Matters

The original CoastSat-Original workflow runs on a schedule (e.g., daily or weekly). Each run:
- Processes only new satellite images since the last run
- Appends new data to existing files
- Recalculates statistics based on all accumulated data

If we validated by running the workflow once from baseline to current, we would:
- ❌ Process all data from scratch (not how the original works)
- ❌ Potentially get different results due to different processing context
- ❌ Not validate the incremental behavior

By running incrementally for each commit:
- ✅ Replicates the exact original behavior
- ✅ Validates that incremental processing works correctly
- ✅ Ensures the workflow can be used to validate a CWL refactor

## Validation Framework Components

### 1. Baseline Data (`baseline/`)

- **Source**: Previous Git commit (e.g., `HEAD~9`)
- **Purpose**: Starting state for validation
- **Contents**:
  - `transects_extended.geojson` - Transect geometries and statistics
  - `data/{site}/transect_time_series.csv` - Raw time series data
  - `data/{site}/transect_time_series_tidally_corrected.csv` - Tidally corrected data
  - `data/{site}/tides.csv` - Tide data
  - `BASELINE_INFO.md` - Metadata about the baseline commit

### 2. Validation Data (`validation/`)

- **Source**: Current Git commit (`HEAD`)
- **Purpose**: Expected final state after all incremental updates
- **Contents**: Same structure as baseline, but with all accumulated data
- **VALIDATION_INFO.md** - Metadata about the validation commit

### 3. Workflow Directory (`workflow/`)

- **Source**: Copy of CoastSat-Original code
- **Purpose**: Execution environment for validation
- **Process**:
  1. Starts with baseline data
  2. Processes each commit incrementally
  3. Accumulates data just like the original
  4. Produces final output for comparison

### 4. Configuration (`config.json`)

Centralized configuration defining:
- **Validation sites**: Which sites to validate (e.g., `["nzd0001", "sar0001"]`)
- **Baseline commit**: Git commit to use as baseline (e.g., `"HEAD~9"`)
- **Date constraints**: Maximum date for image retrieval (auto-extracted from validation data)
- **Workflow settings**: Timeouts, execution methods
- **Comparison settings**: Tolerances, checks to perform

### 5. Comparison Logic

The comparison script (`compare_results.sh`) handles:

- **Common dates only**: Compares only dates that exist in both workflow and validation
- **Tolerance for floating point**: Uses configurable tolerance (default 0.01) for numeric comparisons
- **Site-specific logic**: 
  - NZ sites: Compares `transect_time_series.csv`, `transect_time_series_tidally_corrected.csv`, `tides.csv`
  - SAR sites: Only compares `transect_time_series.csv` (no tidal correction)
- **GeoJSON comparison**: Compares `transects_extended.geojson` statistics for validation sites only

## How to Use for CWL Validation

Once CoastSat is refactored to CWL, this validation framework can be used to validate the CWL implementation:

### Step 1: Run CWL Workflow

Instead of running the original Python scripts, run the CWL workflow:

```bash
# Run CWL workflow with baseline data as input
cwl-runner coastsat-workflow.cwl --baseline-data baseline/ --output-dir workflow/
```

### Step 2: Compare Results

Use the same comparison script:

```bash
./compare_results.sh
```

The comparison will verify that the CWL implementation produces identical results to CoastSat-Original.

### Key Validation Points

1. **Incremental Processing**: The CWL workflow must process data incrementally, not from scratch
2. **Data Accumulation**: New data must be appended to existing files
3. **Statistics Recalculation**: Statistics must be recalculated based on all accumulated data
4. **Exact Match**: Results must match exactly (within tolerance) for all common dates

## Validation Success Criteria

A validation run is considered successful if:

1. ✅ **CSV Files Match**: All common dates in CSV files match exactly (within tolerance)
2. ✅ **GeoJSON Statistics Match**: Statistics in `transects_extended.geojson` match (within tolerance)
3. ✅ **Processing Logic Verified**: The workflow processes data incrementally as expected
4. ⚠️ **Extra Dates in Validation**: Expected - validation may have dates that weren't successfully processed in the validation run (e.g., due to cloud cover)

### Expected Differences

Some differences are expected and acceptable:

- **Extra dates in validation**: If validation has dates that workflow doesn't, this is acceptable if:
  - The workflow attempted to process them (images downloaded)
  - But no valid shorelines were extracted (cloud cover, etc.)
  - The original run successfully extracted shorelines for those dates

- **Small processing differences**: Minor differences (< 1m) in shoreline extraction are acceptable due to:
  - Different image selection
  - Natural variability in processing
  - Floating point precision

## Technical Details

### Date Constraints

To ensure deterministic validation, the framework uses `MAX_DATE.txt`:

- **Purpose**: Constrains image retrieval to a specific maximum date
- **Source**: Extracted from validation data (earliest max date across all sites)
- **Usage**: Prevents the workflow from processing dates beyond what exists in validation data

### Incremental Processing Logic

The batch processing scripts (`batch_process_NZ.py`, `batch_process_sar.py`) handle incremental processing:

1. Read existing CSV file
2. Find maximum date in existing data
3. Set `min_date = max_date + 1 day`
4. Set `max_date = MAX_DATE.txt` (if exists)
5. Download images between `min_date` and `max_date`
6. Extract shorelines and append to existing CSV

### Despike Function

The `despike` function in `tidal_correction.ipynb` removes outliers:

- **Function**: `SDS_transects.identify_outliers(chainage, dates, threshold=40)`
- **Purpose**: Remove data points with large cross-shore changes (likely errors)
- **Validation**: The `verify_despike.sh` script verifies that the despike function matches the original implementation

## Best Practices

### Choosing Validation Sites

- **Select sites with recent updates**: Choose sites that have new data between baseline and validation commits
- **Include both NZ and SAR sites**: Validate both processing paths
- **Avoid new sites**: New sites require full historical download (slow for validation)

### Choosing Baseline Commit

- **Recent enough**: Should have actual data differences (not just code changes)
- **Not too recent**: Should have enough commits between baseline and HEAD to validate incremental processing
- **Recommended**: `HEAD~9` provides good balance (validates ~9 incremental updates)

### Running Validation

1. **Use incremental workflow**: Always use `incremental_validation_workflow.sh` (not `validation_workflow.sh`)
2. **Check logs**: Review workflow logs to understand any differences
3. **Verify despike**: Run `verify_despike.sh` to ensure despike function matches original
4. **Review differences**: Investigate any differences found in comparison

## Troubleshooting

### Common Issues

1. **Extra dates in validation**: Expected - see "Expected Differences" above
2. **Processing differences**: Check logs for cloud cover or image availability issues
3. **MAX_DATE issues**: Ensure MAX_DATE includes all validation sites (not just NZ sites)
4. **Missing data**: Verify baseline and validation data were extracted correctly

See `docs/TROUBLESHOOTING.md` for more detailed troubleshooting guidance.

## Future: CWL Validation

When validating a CWL refactor:

1. **Replace workflow execution**: Instead of running Python scripts, run CWL workflow
2. **Same comparison logic**: Use the same `compare_results.sh` script
3. **Same success criteria**: Results must match exactly (within tolerance)
4. **Document differences**: Any differences should be documented and justified

The validation framework is designed to be workflow-agnostic - it compares inputs and outputs, not the implementation details.

