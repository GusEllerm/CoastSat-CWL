# CoastSat Validation Framework

A validation framework for testing the CoastSat-Original workflow's incremental data processing. This framework validates that the workflow correctly processes data incrementally (as it does in production) and will be used to validate a future CWL (Common Workflow Language) refactor of CoastSat.

## Purpose

This validation framework serves two primary purposes:

1. **Validate CoastSat-Original**: Verify that the incremental data processing workflow works correctly by simulating the transition from a previous dataset state to the current state.

2. **Validate CWL Refactor**: Once CoastSat is refactored to CWL, this same framework will validate that the CWL implementation produces identical results to CoastSat-Original.

## Quick Start

### Prerequisites

- **Docker** (recommended for macOS compatibility)
- **Google Earth Engine credentials** (`.private-key.json` file)
- **NIWA Tide API key** (optional, for tidal correction)

### Basic Usage

1. **Configure validation** (optional - defaults work):
   ```bash
   # Edit config.json to change validation sites or baseline commit
   ```

2. **Run incremental validation**:
   ```bash
   cd CoastSat-Validation
   ./incremental_validation_workflow.sh
   ```

This single command will:
- Extract baseline and validation data from Git
- Run the workflow incrementally for each commit
- Compare results and report any differences

### What Gets Validated

The framework validates:
- ✅ **Incremental Processing**: Workflow processes only new data since previous commit
- ✅ **Data Accumulation**: New data is appended to existing files (not overwritten)
- ✅ **Statistics Recalculation**: Statistics are recalculated based on all accumulated data
- ✅ **Exact Match**: Results match validation data exactly (within tolerance) for all common dates

## Documentation

- **[Validation Methodology](docs/VALIDATION_METHODOLOGY.md)** - Comprehensive explanation of how the validation works and why it's designed this way
- **[How It Works](docs/HOW_IT_WORKS.md)** - Detailed technical explanation of the validation framework
- **[Configuration Guide](docs/README_CONFIG.md)** - Configuration options and settings
- **[Documentation Index](docs/INDEX.md)** - Complete documentation index

## Directory Structure

```
CoastSat-Validation/
├── config.json              # Centralized configuration
├── baseline/                # Data from previous commit (starting state)
│   ├── BASELINE_INFO.md     # Baseline commit metadata
│   ├── transects_extended.geojson
│   └── data/                # Site-specific baseline data
├── validation/              # Data from current commit (expected results)
│   ├── VALIDATION_INFO.md   # Validation commit metadata
│   ├── transects_extended.geojson
│   └── data/                # Site-specific validation data
├── workflow/                # Workflow execution environment
│   ├── batch_process_NZ.py
│   ├── batch_process_sar.py
│   ├── tidal_correction.ipynb
│   ├── slope_estimation.ipynb
│   ├── linear_models.ipynb
│   └── data/                # Workflow output (compared against validation)
├── scripts/                 # Utility scripts
│   └── load_config.py       # Configuration loader
├── docs/                    # Documentation
│   ├── VALIDATION_METHODOLOGY.md
│   ├── HOW_IT_WORKS.md
│   └── ...
└── *.sh                     # Main workflow scripts
```

## Main Scripts

### `incremental_validation_workflow.sh` ⭐ **Recommended**

Complete incremental validation workflow:
- Extracts baseline and validation data
- Runs workflow incrementally for each commit (HEAD~9 → HEAD~8 → ... → HEAD)
- Compares final results
- **This is the script to use for validation**

### `setup_validation.sh`

Initial setup - extracts baseline and validation data from Git:
```bash
./setup_validation.sh [--baseline-commit COMMIT] [--sites SITES]
```

### `prepare_workflow.sh`

Prepares workflow directory for execution:
- Copies baseline data
- Filters reference files to validation sites
- Sets up MAX_DATE constraint

### `compare_results.sh`

Compares workflow output against validation data:
- Compares GeoJSON files (statistics)
- Compares CSV files (time series data)
- Reports differences with details

### `verify_despike.sh`

Verifies that the despike function matches the original implementation.

## Configuration

Edit `config.json` to configure validation:

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

See [docs/README_CONFIG.md](docs/README_CONFIG.md) for detailed configuration options.

## How It Works

### The Problem

CoastSat-Original processes data **incrementally**:
- Each run processes only new data since the last commit
- Data accumulates - new observations are appended to existing files
- Statistics are recalculated based on all accumulated data

To validate this correctly, we must replicate this incremental behavior.

### The Solution

The validation framework:

1. **Extracts baseline data** from a previous commit (e.g., `HEAD~9`)
2. **Extracts validation data** from current commit (`HEAD`)
3. **Runs workflow incrementally** for each commit between baseline and HEAD:
   - HEAD~9 → HEAD~8 (processes new data, updates files)
   - HEAD~8 → HEAD~7 (processes new data, updates files)
   - ... continues until HEAD
4. **Compares results** - workflow output vs validation data

This replicates the exact original behavior and validates that incremental processing works correctly.

### Why Incremental?

If we ran the workflow once from baseline to current, we would:
- ❌ Process all data from scratch (not how the original works)
- ❌ Potentially get different results
- ❌ Not validate the incremental behavior

By running incrementally:
- ✅ Replicates exact original behavior
- ✅ Validates incremental processing
- ✅ Ensures workflow can validate CWL refactor

See [docs/VALIDATION_METHODOLOGY.md](docs/VALIDATION_METHODOLOGY.md) for comprehensive explanation.

## Validation for CWL Refactor

Once CoastSat is refactored to CWL, this framework will validate the CWL implementation:

1. **Run CWL workflow** instead of Python scripts
2. **Use same comparison logic** (`compare_results.sh`)
3. **Verify exact match** - CWL results must match CoastSat-Original

The framework is **workflow-agnostic** - it validates inputs and outputs, not implementation details.

## Expected Results

A successful validation shows:

- ✅ **Perfect match** for all common dates (e.g., nzd0001: 0.000000 diff)
- ⚠️ **Extra dates in validation** - Expected if validation has dates that weren't successfully processed in validation run
- ⚠️ **Small processing differences** - Acceptable if < 1m (due to natural variability)

### Example Output

```
Site: nzd0001
ℹ Comparing 193 common dates (workflow has 0 extra, validation has 1 extra)
✓ Match: nzd0001/transect_time_series.csv (max diff: 0.000000)
✓ Match: nzd0001/transect_time_series_tidally_corrected.csv (max diff: 0.000000)
✓ Match: nzd0001/tides.csv (max diff: 0.000000)
```

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues and solutions.

Common issues:
- **Extra dates in validation**: Expected - see "Expected Results" above
- **Processing differences**: Check logs for cloud cover or image availability
- **MAX_DATE issues**: Ensure MAX_DATE includes all validation sites

## Key Files

### Data Files
- `transects_extended.geojson` - Transect geometries and statistics
- `data/{site}/transect_time_series.csv` - Raw time series data
- `data/{site}/transect_time_series_tidally_corrected.csv` - Tidally corrected data
- `data/{site}/tides.csv` - Tide data (NZ sites only)

### Metadata Files
- `baseline/BASELINE_INFO.md` - Baseline commit metadata
- `validation/VALIDATION_INFO.md` - Validation commit metadata

## Contributing

When modifying the validation framework:

1. **Update documentation** - Keep `docs/` up to date
2. **Test incrementally** - Ensure incremental workflow still works
3. **Verify despike** - Run `verify_despike.sh` after changes
4. **Document changes** - Update relevant documentation

## License

This validation framework is part of the CoastSat-CWL project.
