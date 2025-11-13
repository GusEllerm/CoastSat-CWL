# Setup Reference

This guide summarises the prerequisites and configuration required to run the minimal CoastSat workflow.

## Requirements

- Python 3.8 or later
- `pip`
- Access to Google Earth Engine (service account)
- NIWA Tide API key
- GDAL binaries compatible with the Python bindings (install via Homebrew/apt/conda as appropriate)

## Install Dependencies

### Option 1: Use Virtual Environment (Recommended)

Create and activate a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate  # On macOS/Linux
# or
.venv\Scripts\activate  # On Windows
```

Then install dependencies:

```bash
pip install -r requirements.txt
```

**Note:** Always activate the virtual environment before running the workflow.

### Option 2: Install Globally

```bash
pip install -r requirements.txt
```

**Warning:** Installing globally may cause conflicts with other Python projects.

If GDAL wheels are unavailable for your platform, install matching system binaries first and then reinstall the Python package.

## Credentials

### Google Earth Engine
1. Create or reuse a Google Cloud project.
2. Enable the **Earth Engine API**.
3. Provision a service account (minimum role: *Earth Engine User*).
4. Register the service account at <https://code.earthengine.google.com/register>.
5. Download the JSON key and save it as `.private-key.json`.

**Credential Location:** Place `.private-key.json` in either:
- Repository root (`CoastSat-CWL/.private-key.json`) - **Recommended** for sharing between `CoastSat-minimal/` and `CoastSat-CWL/`
- Project root (`CoastSat-minimal/.private-key.json`) - Alternative for project-specific credentials

The scripts will automatically search both locations.

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

**Credential Location:** Place `.env` in either:
- Repository root (`CoastSat-CWL/.env`) - **Recommended** for sharing between `CoastSat-minimal/` and `CoastSat-CWL/`
- Project root (`CoastSat-minimal/.env`) - Alternative for project-specific credentials

The scripts will automatically search both locations.

Environment override:
```bash
export NIWA_TIDE_API_KEY=your_api_key
```

## Configuration

- Filtered inputs (`inputs/*.geojson`) are already provided; regenerate with `python3 scripts/setup/filter_inputs_simple.py` if the source data changes.
- The workflow reads Google Earth Engine credentials from `.private-key.json` (searches repository root first, then project root) and loads `.env` via `python-dotenv` (searches both locations).
- **Shared Credentials:** For sharing credentials between `CoastSat-minimal/` and `CoastSat-CWL/`, place `.private-key.json` and `.env` in the repository root (`CoastSat-CWL/`).
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
- `.private-key.json` is present in repository root or project root (excluded from git).
- `.env` contains `NIWA_TIDE_API_KEY` in repository root or project root (and optional test variables).
- `python3 -c "import ee"` succeeds after initialising with the service account credentials.
- `python3 tests/validate_outputs.py` reports no missing output files after a workflow run.

Maintain credential hygiene: never commit `.private-key.json` or `.env`, and rotate keys if exposure is suspected.

