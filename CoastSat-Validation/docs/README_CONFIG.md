# Configuration System

The CoastSat validation framework uses a centralized configuration file (`config.json`) to define validation parameters.

## Configuration File

Location: `CoastSat-Validation/config.json`

### Structure

```json
{
  "validation_sites": [
    "nzd0001",
    "sar0001"
  ],
  "baseline_commit": "HEAD~15",
  "max_date": {
    "strategy": "auto",
    "description": "auto = extract from validation data, or specify YYYY-MM-DD"
  },
  "workflow": {
    "notebook_timeout_seconds": 1800,
    "use_safe_notebook_execution": true
  },
  "comparison": {
    "csv_tolerance": 0.01,
    "check_transects_extended": true,
    "check_csv_files": true
  }
}
```

### Fields

- **`validation_sites`**: Array of site IDs to use for validation (e.g., `["nzd0001", "sar0001"]`)
- **`baseline_commit`**: Git commit/tag to use as baseline (e.g., `"HEAD~15"` or `"abc123"`)
- **`max_date.strategy`**: 
  - `"auto"`: Extract max date from validation data (default)
  - `"YYYY-MM-DD"`: Use specific date as upper bound
- **`workflow.notebook_timeout_seconds`**: Timeout for notebook execution (default: 1800)
- **`workflow.use_safe_notebook_execution`**: Use `execute_notebook_safe.py` (default: true)
- **`comparison.csv_tolerance`**: Tolerance for CSV numeric comparisons (default: 0.01)

## Usage

### Loading Config in Python

```python
from load_config import load_config, get_validation_sites

# Load full config
config = load_config()

# Get specific values
sites = get_validation_sites()
baseline_commit = get_baseline_commit()
```

### Using Config in Scripts

All scripts automatically load from `config.json`:
- `setup_validation.sh` - Uses `baseline_commit` and `validation_sites`
- `prepare_workflow.sh` - Uses `validation_sites` for filtering
- `batch_process_NZ.py` - Uses `validation_sites` to filter NZ sites
- `batch_process_sar.py` - Uses `validation_sites` to filter SAR sites
- `make_xlsx.py` - Uses `validation_sites` to process only validation sites

### Overriding Config

Command-line options override config values:
```bash
./setup_validation.sh --baseline-commit HEAD~20 --sites "nzd0001 nzd0002"
```

## Benefits

1. **No Hardcoding**: Sites and parameters defined in one place
2. **Easy Updates**: Change sites by editing `config.json`
3. **Reproducibility**: Config file can be versioned with results
4. **Flexibility**: Easy to add new validation sites or change parameters

## Example: Adding a New Site

1. Edit `config.json`:
   ```json
   {
     "validation_sites": [
       "nzd0001",
       "sar0001",
       "nzd0002"
     ]
   }
   ```

2. Run setup:
   ```bash
   ./setup_validation.sh
   ```

3. All scripts will automatically use the new site list!

