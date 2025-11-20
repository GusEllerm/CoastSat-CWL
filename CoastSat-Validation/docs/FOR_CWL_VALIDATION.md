# Using This Framework for CWL Validation

This document explains how to use this validation framework to validate a CWL (Common Workflow Language) refactor of CoastSat.

## Overview

Once CoastSat is refactored to CWL, this validation framework can be used to ensure the CWL implementation produces **identical results** to CoastSat-Original.

## Key Principle

**The validation framework is workflow-agnostic** - it validates inputs and outputs, not implementation details. This makes it perfect for validating a CWL refactor.

## Validation Process for CWL

### Step 1: Prepare Baseline and Validation Data

This step is the same as for CoastSat-Original validation:

```bash
./setup_validation.sh
```

This extracts:
- **Baseline data** from a previous commit (e.g., `HEAD~9`)
- **Validation data** from current commit (`HEAD`)

### Step 2: Run CWL Workflow (Instead of Python Scripts)

Instead of running the Python scripts, run the CWL workflow:

```bash
# Option 1: Run CWL workflow directly
cwl-runner coastsat-workflow.cwl \
  --baseline-data baseline/ \
  --output-dir workflow/ \
  --config config.json

# Option 2: Use a wrapper script (recommended)
./run_cwl_validation.sh
```

The CWL workflow should:
1. **Process incrementally** - Start with baseline data, process each commit
2. **Accumulate data** - Append new data to existing files
3. **Recalculate statistics** - Update `transects_extended.geojson` with new statistics

### Step 3: Compare Results

Use the same comparison script:

```bash
./compare_results.sh
```

This will compare:
- CWL workflow output vs validation data
- Verify exact match (within tolerance) for all common dates

## CWL Workflow Requirements

For the CWL workflow to be validated, it must:

### 1. Support Incremental Processing

The CWL workflow must process data incrementally, not from scratch:

- **Read existing data**: Start with baseline data from `baseline/` directory
- **Process new data only**: For each commit, process only new data since previous commit
- **Append to existing**: Add new observations to existing CSV files (don't overwrite)

### 2. Match Input/Output Structure

The CWL workflow must use the same input/output structure:

**Inputs**:
- `baseline/transects_extended.geojson`
- `baseline/data/{site}/transect_time_series.csv`
- `baseline/data/{site}/transect_time_series_tidally_corrected.csv` (NZ sites)
- `baseline/data/{site}/tides.csv` (NZ sites)
- `workflow/polygons.geojson` (filtered to validation sites)
- `workflow/shorelines.geojson` (filtered to validation sites)
- `workflow/MAX_DATE.txt` (date constraint)

**Outputs** (in `workflow/`):
- `transects_extended.geojson` (updated with new statistics)
- `data/{site}/transect_time_series.csv` (appended with new data)
- `data/{site}/transect_time_series_tidally_corrected.csv` (NZ sites, appended)
- `data/{site}/tides.csv` (NZ sites, appended)
- `data/{site}/{site}.xlsx` (NZ sites, regenerated)

### 3. Replicate Processing Logic

The CWL workflow must replicate the same processing logic:

1. **Batch Processing**:
   - Read existing CSV, find max date
   - Set `min_date = max_date + 1 day`
   - Download images between `min_date` and `MAX_DATE`
   - Extract shorelines and append to CSV

2. **Tidal Correction** (first pass):
   - Fetch tide data for new dates
   - Apply corrections using existing beach slopes

3. **Slope Estimation**:
   - Calculate beach slopes from tidally-corrected data
   - Update `transects_extended.geojson`

4. **Tidal Correction** (second pass):
   - Re-apply corrections with new slopes
   - Apply despike function (remove outliers)

5. **Linear Models**:
   - Calculate trends, R², RMSE, MAE, MSE
   - Update `transects_extended.geojson`

6. **Excel Generation**:
   - Generate Excel reports for NZ sites

### 4. Handle Incremental Updates

The CWL workflow must handle incremental updates correctly:

- **For each commit** (HEAD~9 → HEAD~8 → ... → HEAD):
  - Read current state (from previous step)
  - Process only new data
  - Update files incrementally
  - Recalculate statistics based on all accumulated data

## Integration with Validation Framework

### Option 1: Modify `incremental_validation_workflow.sh`

Replace the workflow execution step:

```bash
# Old (Python scripts):
$DOCKER_COMPOSE_CMD run --rm coastsat-validation bash -c 'cd /app && ./update_validation.sh'

# New (CWL):
cwl-runner coastsat-workflow.cwl \
  --baseline-data "$WORKFLOW_DIR" \
  --output-dir "$WORKFLOW_DIR" \
  --config "$CONFIG_FILE" \
  --commit "$NEXT_COMMIT"
```

### Option 2: Create CWL-Specific Script

Create `incremental_cwl_validation_workflow.sh`:

```bash
#!/bin/bash
# Similar to incremental_validation_workflow.sh
# But runs CWL workflow instead of Python scripts

# ... (same setup and preparation) ...

# Run CWL workflow for each commit
for commit in "${COMMITS[@]}"; do
    cwl-runner coastsat-workflow.cwl \
      --input-data "$WORKFLOW_DIR" \
      --output-dir "$WORKFLOW_DIR" \
      --max-date "$MAX_DATE" \
      --commit "$commit"
done

# Compare results (same as before)
./compare_results.sh
```

## Success Criteria for CWL Validation

The CWL implementation is validated if:

1. ✅ **CSV Files Match**: All common dates match exactly (within tolerance)
2. ✅ **GeoJSON Statistics Match**: Statistics match (within tolerance)
3. ✅ **Incremental Behavior Verified**: Data accumulates correctly
4. ✅ **Processing Logic Verified**: Same results as CoastSat-Original

## Differences from CoastSat-Original Validation

| Aspect | CoastSat-Original | CWL Refactor |
|--------|------------------|--------------|
| **Execution** | Python scripts in Docker | CWL workflow |
| **Implementation** | Original code | Refactored to CWL |
| **Validation** | Same framework | Same framework |
| **Comparison** | Same script | Same script |
| **Success Criteria** | Same | Same |

The validation framework doesn't care about the implementation - it only validates that inputs and outputs match.

## Benefits of This Approach

1. **Workflow-Agnostic**: Validates behavior, not implementation
2. **Reusable**: Same framework for original and CWL
3. **Comprehensive**: Validates entire workflow, not just individual steps
4. **Deterministic**: Uses MAX_DATE constraints for reproducible results
5. **Incremental**: Validates the actual production behavior

## Next Steps

1. **Refactor CoastSat to CWL**: Create CWL workflow definitions
2. **Test Incremental Processing**: Ensure CWL workflow processes data incrementally
3. **Run Validation**: Use this framework to validate CWL implementation
4. **Verify Match**: Ensure CWL results match CoastSat-Original exactly

## Questions?

- See [VALIDATION_METHODOLOGY.md](VALIDATION_METHODOLOGY.md) for methodology details
- See [HOW_IT_WORKS.md](HOW_IT_WORKS.md) for technical details
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues

