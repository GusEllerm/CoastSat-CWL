# How the Validation Framework Works

## Overview

This document provides a detailed technical explanation of how the CoastSat validation framework works, step by step.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CoastSat-Original                        │
│  (Git repository with commit history)                       │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Extract
                          ▼
        ┌─────────────────────────────────────┐
        │      Baseline Data (HEAD~9)          │
        │  - transects_extended.geojson        │
        │  - data/{site}/*.csv                 │
        └─────────────────────────────────────┘
                          │
                          │ Copy to workflow/
                          ▼
        ┌─────────────────────────────────────┐
        │      Workflow Execution               │
        │  Process incrementally:               │
        │  HEAD~9 → HEAD~8 → ... → HEAD        │
        │  Each step adds new data              │
        └─────────────────────────────────────┘
                          │
                          │ Compare
                          ▼
        ┌─────────────────────────────────────┐
        │      Validation Data (HEAD)          │
        │  - transects_extended.geojson        │
        │  - data/{site}/*.csv                 │
        └─────────────────────────────────────┘
```

## Step-by-Step Process

### 1. Setup Phase (`setup_validation.sh`)

**Purpose**: Extract baseline and validation data from Git history

**Process**:
1. Reads configuration from `config.json` (or command-line arguments)
2. Extracts baseline data from specified commit (e.g., `HEAD~9`)
   - Uses `git show` to extract files from that commit
   - Copies to `baseline/` directory
3. Extracts validation data from current commit (`HEAD`)
   - Uses `git show` to extract files from HEAD
   - Copies to `validation/` directory
4. Generates metadata files:
   - `baseline/BASELINE_INFO.md` - Commit hash, date, author, message, tag
   - `validation/VALIDATION_INFO.md` - Same for validation commit
5. Copies workflow code from `CoastSat-Original/` to `workflow/`

**Key Files Extracted**:
- `transects_extended.geojson` - Main output with transect statistics
- `data/{site}/transect_time_series.csv` - Raw time series
- `data/{site}/transect_time_series_tidally_corrected.csv` - Tidally corrected
- `data/{site}/tides.csv` - Tide data (NZ sites only)

### 2. Preparation Phase (`prepare_workflow.sh`)

**Purpose**: Prepare the workflow directory for execution

**Process**:
1. **Cleanup**: Removes old data and regenerated files
2. **Copy Baseline Data**: Copies baseline data to `workflow/data/`
3. **Copy Reference Files**: 
   - Copies `polygons.geojson` and `shorelines.geojson` from original (not baseline)
   - This ensures new sites added after baseline are available
4. **Filter Reference Files**: Filters to only include validation sites from `config.json`
5. **Extract MAX_DATE**: 
   - Reads all validation `transect_time_series.csv` files
   - Finds the earliest maximum date across all sites
   - Writes to `workflow/MAX_DATE.txt`
   - This ensures deterministic validation (same date range for all sites)
6. **Create Update Script**: Generates `update_validation.sh` (original `update.sh` without git operations)

**Why Copy from Original?**
- New sites (added after baseline) won't exist in baseline data
- Copying from original ensures all sites are available for filtering
- Filtering then restricts to only validation sites

### 3. Incremental Execution Phase (`incremental_validation_workflow.sh`)

**Purpose**: Run the workflow incrementally for each commit, replicating original behavior

**Process**:
1. **Get Commit List**: 
   - Lists all commits between baseline and HEAD (inclusive)
   - Uses `git rev-list --reverse HEAD~9..HEAD` then appends HEAD

2. **For Each Commit** (HEAD~9 → HEAD~8 → ... → HEAD):
   a. **Set MAX_DATE**: 
      - Extracts max date from that commit's data
      - Checks all validation sites (NZ and SAR)
      - Sets `MAX_DATE.txt` to the maximum date across all sites
   
   b. **Run Workflow**:
      - Executes `update_validation.sh` in Docker
      - The workflow reads existing CSV files
      - Finds max date in existing data
      - Sets `min_date = max_date + 1 day`
      - Downloads images between `min_date` and `MAX_DATE`
      - Extracts shorelines and appends to CSV
      - Runs notebooks to update statistics
   
   c. **Data Accumulates**:
      - Each step adds new data to existing files
      - Statistics are recalculated based on all accumulated data
      - Just like the original workflow

3. **Final State**: After processing all commits, workflow directory contains final results

**Key Insight**: Each commit processes only new data since the previous commit, exactly like the original workflow.

### 4. Comparison Phase (`compare_results.sh`)

**Purpose**: Compare workflow output against validation data

**Process**:
1. **GeoJSON Comparison** (Docker):
   - Loads `workflow/transects_extended.geojson` and `validation/transects_extended.geojson`
   - Filters to validation sites only (from `config.json`)
   - Compares transect IDs (must match)
   - Compares numeric columns (n_points, trend, r2_score, rmse, mae, mse, intercept, beach_slope)
   - Uses tolerance (default 0.01) for floating point differences

2. **CSV Comparison** (Docker, per site):
   - For each validation site:
     - Compares `transect_time_series.csv`
     - For NZ sites: Also compares `transect_time_series_tidally_corrected.csv` and `tides.csv`
     - Uses "common dates only" mode:
       - Finds dates that exist in both workflow and validation
       - Compares only those dates
       - Reports how many extra dates each has
     - Uses tolerance for numeric differences

3. **Report Results**:
   - Shows matches (✓) and differences (⚠)
   - Provides details on any differences found

**Why "Common Dates Only"?**
- Validation may have dates that workflow doesn't (e.g., cloud cover prevented extraction)
- Workflow may have dates that validation doesn't (shouldn't happen, but possible)
- Comparing only common dates validates that the workflow correctly processes the data it does extract

## Key Components

### Batch Processing Scripts

**`batch_process_NZ.py`** and **`batch_process_sar.py`**:

1. **Read Existing Data**:
   ```python
   df = pd.read_csv(f"data/{sitename}/transect_time_series.csv")
   min_date = str(df.dates.max().date() + timedelta(days=1))
   ```

2. **Read MAX_DATE Constraint**:
   ```python
   with open("MAX_DATE.txt", "r") as f:
       max_date = f.read().strip()
   ```

3. **Download Images**:
   ```python
   inputs = {
       "dates": [min_date, max_date],  # Only new images
       ...
   }
   metadata = SDS_download.retrieve_images(inputs)
   ```

4. **Extract and Append**:
   - Extracts shorelines from new images
   - Appends to existing CSV (doesn't overwrite)

### Notebook Execution

**`tidal_correction.ipynb`**, **`slope_estimation.ipynb`**, **`linear_models.ipynb`**:

- Executed using `execute_notebook_safe.py` (patches IPython magic issues)
- Each notebook reads existing data, processes it, and updates outputs
- Statistics are recalculated based on all accumulated data

### Despike Function

**Location**: `tidal_correction.ipynb`

**Function**:
```python
def despike(chainage, threshold=40):
    chainage = chainage.dropna()
    chainage, dates = SDS_transects.identify_outliers(
        chainage.tolist(), 
        chainage.index.tolist(), 
        threshold
    )
    return pd.Series(chainage, index=dates)
```

**Purpose**: Removes outliers with large cross-shore changes (likely errors)

**Validation**: `verify_despike.sh` verifies the function matches the original implementation

## Data Flow

```
Baseline (HEAD~9)
    │
    ├─> workflow/data/  (copied by prepare_workflow.sh)
    │
    ├─> Process HEAD~9 → HEAD~8
    │   ├─> Download new images
    │   ├─> Extract shorelines
    │   ├─> Append to CSV
    │   └─> Update statistics
    │
    ├─> Process HEAD~8 → HEAD~7
    │   └─> (same process, data accumulates)
    │
    ├─> ... (continue for each commit)
    │
    └─> Final State (after processing HEAD)
        │
        └─> Compare with Validation (HEAD)
```

## Deterministic Validation

To ensure deterministic results:

1. **MAX_DATE Constraint**: All sites use the same maximum date (from validation data)
2. **Common Dates Comparison**: Only compares dates that exist in both datasets
3. **Tolerance for Differences**: Uses configurable tolerance for floating point comparisons
4. **Site Filtering**: Only processes and compares validation sites from `config.json`

## Docker Environment

The workflow runs in Docker to ensure:
- **Consistent Environment**: Ubuntu-based (matches original)
- **Dependency Isolation**: All Python packages in controlled environment
- **Cross-Platform**: Works on macOS (user's system) and Linux (original system)

**Key Files**:
- `Dockerfile`: Defines the Docker image with all dependencies
- `docker-compose.yml`: Configures volumes and environment
- `workflow/requirements.txt`: Python package dependencies

## Configuration System

**`config.json`** provides centralized configuration:

```json
{
  "validation_sites": ["nzd0001", "sar0001"],
  "baseline_commit": "HEAD~9",
  "max_date": {
    "strategy": "auto"
  },
  "workflow": {
    "notebook_timeout_seconds": 1800
  },
  "comparison": {
    "csv_tolerance": 0.01
  }
}
```

**`scripts/load_config.py`** provides Python functions to load configuration:
- `get_validation_sites()` - Returns list of site IDs
- `get_baseline_commit()` - Returns baseline commit reference
- `get_csv_tolerance()` - Returns comparison tolerance

## Error Handling

The framework includes robust error handling:

1. **Empty File Handling**: Batch processing scripts handle empty CSV files gracefully
2. **Missing Data**: Comparison script handles missing files
3. **Docker Timeouts**: Comparison uses timeouts to prevent hanging
4. **Path Resolution**: Scripts handle both host and Docker paths correctly

## Logging

- **Workflow Execution**: Logged to `workflow_execution.log`
- **Incremental Steps**: Each step logs to `workflow_incremental_{N}.log`
- **Comparison Results**: Output to console with detailed differences

## Validation Success

A validation is considered successful if:

1. ✅ All CSV files match for common dates (within tolerance)
2. ✅ GeoJSON statistics match for validation sites (within tolerance)
3. ✅ Processing logic verified (incremental behavior confirmed)
4. ⚠️ Extra dates in validation are acceptable (explained in comparison output)

The framework is designed to be **workflow-agnostic** - it validates inputs and outputs, not implementation details. This makes it suitable for validating a CWL refactor.

