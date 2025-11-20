# Deterministic Validation with Date Constraints

## Overview

To ensure deterministic validation results, the workflow now constrains image retrieval to a maximum date that matches the validation dataset. This prevents the workflow from processing newer data that wasn't available when the validation dataset was created.

## How It Works

### 1. Max Date Extraction

When `prepare_workflow.sh` runs, it:
1. Extracts the maximum date from each site's validation CSV file
2. Uses the **earliest** max date across all validation sites
3. Creates `workflow/MAX_DATE.txt` with this date

### 2. Date Constraint in Batch Processing

Both `batch_process_NZ.py` and `batch_process_sar.py` now:
1. Check for `MAX_DATE.txt` in the workflow directory
2. If found, use it as the upper bound for image retrieval
3. If not found, default to `2030-12-30` (all available imagery)

### 3. Code Changes

**batch_process_NZ.py** and **batch_process_sar.py**:
```python
# Read max date from MAX_DATE.txt if it exists (for deterministic validation)
max_date = '2030-12-30'  # Default: all available imagery
max_date_file = 'MAX_DATE.txt'
if os.path.exists(max_date_file):
    with open(max_date_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                max_date = line
                print(f"Using validation max date: {max_date}")
                break

inputs = {
    "polygon": list(poly.geometry[sitename].exterior.coords),
    "dates": [min_date, max_date],  # Constrained by validation max date
    ...
}
```

## Benefits

1. **Deterministic Results**: Workflow will always produce the same results for a given validation dataset
2. **No Timing Dependencies**: Results don't depend on when the workflow is executed
3. **Exact Matching**: Workflow results will match validation data exactly (within processing tolerances)

## Usage

The date constraint is automatically applied when you run:
```bash
./prepare_workflow.sh
```

This will:
1. Extract max dates from validation data
2. Create `workflow/MAX_DATE.txt`
3. Ensure batch processing scripts use this constraint

## Manual Override

If you need to override the max date, you can:
1. Edit `workflow/MAX_DATE.txt` directly
2. Or delete it to use all available imagery (default behavior)

## Single Max Date Constraint

The system uses a **single max date** stored in `MAX_DATE.txt` that applies to all sites. This date is set to the **earliest max date** across all validation sites to ensure no site processes data beyond its validation limit.

This approach:
- Simplifies the implementation (one file instead of per-site)
- Ensures deterministic validation (all sites use the same constraint)
- Uses the most conservative date (earliest) to guarantee no site exceeds validation

## Example

If validation data has:
- `nzd0001`: max date = 2025-09-25
- `sar0001`: max date = 2025-10-06

Then `MAX_DATE.txt` will contain `2025-09-25` (the earliest), ensuring both sites are constrained to this date. This means:
- `nzd0001` processes data up to 2025-09-25 (matches validation) ✓
- `sar0001` processes data up to 2025-09-25 (may have less data than validation, but won't exceed it) ✓

