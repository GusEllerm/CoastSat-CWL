# Troubleshooting Validation Workflow

## Issue: Step 3 (Tidal Correction) Failed

### Problem
The workflow failed at step 3 when executing `tidal_correction.ipynb` with two issues:

1. **Missing `autotime` module**: The notebook tries to load an IPython extension that wasn't installed
2. **Missing `NIWA_API_KEY`**: The notebook requires a NIWA Tide API key to fetch tide data

### Solutions Applied

#### 1. Fixed autotime Extension
- **Issue**: `ModuleNotFoundError: No module named 'autotime'`
- **Fix**: 
  - Added `ipython-autotime` to Dockerfile
  - Made the extension load optional (wrapped in try/except)
  - Updated notebook to handle missing extension gracefully

#### 2. Made NIWA API Key Optional
- **Issue**: `KeyError: 'NIWA_API_KEY'` when trying to fetch tides
- **Fix**:
  - Updated notebook to check if `tides.csv` already exists before fetching
  - Made API key optional (uses `os.environ.get()` instead of `os.environ[]`)
  - Since baseline data includes `tides.csv` files, the workflow should skip API calls

### Current Status

✅ **Autotime issue**: Fixed  
⚠️ **NIWA API Key**: Made optional, but may still need it for new sites

### Next Steps

1. **If you have a NIWA API key**:
   ```bash
   # Create .env file
   echo "NIWA_API_KEY=your_key_here" > .env
   ```

2. **If you don't have a NIWA API key**:
   - The workflow should use existing `tides.csv` files from baseline
   - If it still fails, we may need to modify the notebook further

3. **Re-run the workflow**:
   ```bash
   docker compose run --rm coastsat-validation bash -c "cd /app && ./update_validation.sh"
   ```

### Checking Logs

If the workflow fails again, check:
- Docker logs: `docker compose logs`
- Notebook output: Check the error message for which cell failed
- Data files: Verify `tides.csv` files exist in `workflow/data/{site}/`

### Alternative: Skip Tidal Correction for Validation

If the API key is not available and you want to test the rest of the workflow:

1. Comment out tidal correction steps in `update_validation.sh`
2. Use existing `tides.csv` files from baseline
3. Proceed with slope estimation and linear models

This would validate the core workflow logic even without new tide data.

