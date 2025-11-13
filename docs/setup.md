# Setup Reference

This guide summarises the prerequisites and configuration required to run the minimal CoastSat workflow.

## Requirements

- Python 3.8 or later
- `pip`
- Access to Google Earth Engine (service account)
- NIWA Tide API key
- GDAL binaries compatible with the Python bindings (install via Homebrew/apt/conda as appropriate)

## Install Dependencies

```bash
pip install -r requirements.txt
```

If GDAL wheels are unavailable for your platform, install matching system binaries first and then reinstall the Python package.

## Credentials

### Google Earth Engine
1. Create or reuse a Google Cloud project.
2. Enable the **Earth Engine API**.
3. Provision a service account (minimum role: *Earth Engine User*).
4. Register the service account at <https://code.earthengine.google.com/register>.
5. Download the JSON key and save it as `.private-key.json` in the project root (listed in `.gitignore`).

Optional environment override:
```bash
export GEE_SERVICE_ACCOUNT=service-account@project.iam.gserviceaccount.com
export GEE_PRIVATE_KEY_PATH=.private-key.json
```

### NIWA Tide API
1. Create an account at <https://developer.niwa.co.nz/> and generate an API key.
2. Copy `env.example` to `.env` and populate the key:
   ```bash
   cp env.example .env
   # Edit .env
   NIWA_TIDE_API_KEY=your_api_key
   ```

Environment override:
```bash
export NIWA_TIDE_API_KEY=your_api_key
```

## Configuration

- Filtered inputs (`inputs/*.geojson`) are already provided; regenerate with `python3 scripts/setup/filter_inputs_simple.py` if the source data changes.
- The workflow reads Google Earth Engine credentials from `.private-key.json` by default and loads `.env` via `python-dotenv`.
- Optional test mode variables (set in `.env`) limit data retrieval:
  ```env
  TEST_MODE=true
  TEST_START_DATE=2024-06-01
  TEST_END_DATE=2024-12-31
  TEST_SITES=nzd0001
  TEST_SATELLITES=L8,L9
  ```

## Verification Checklist

- `inputs/polygons.geojson`, `inputs/shorelines.geojson`, `inputs/transects_extended.geojson` exist.
- `.private-key.json` is present and excluded from git.
- `.env` contains `NIWA_TIDE_API_KEY` (and optional test variables).
- `python3 -c "import ee"` succeeds after initialising with the service account credentials.
- `python3 tests/validate_outputs.py` reports no missing output files after a workflow run.

Maintain credential hygiene: never commit `.private-key.json` or `.env`, and rotate keys if exposure is suspected.

