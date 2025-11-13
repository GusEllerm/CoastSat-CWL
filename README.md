# CoastSat-CWL Minimal Kit

This repository contains a pared-down CoastSat environment that preserves the coastal shoreline processing pipeline while removing legacy visualisation code and excess data. It serves as the staging area for refactoring the workflow into CWL components and provides tooling to verify behaviour against the published CoastSat outputs.

## Contents

- `scripts/` – batch processing, tidal correction, slope estimation, linear models, and XLSX generation.
- `inputs/` – filtered GeoJSON inputs for the representative sites used in testing.
- `data/` – workspace outputs written by the minimal workflow.
- `tests/` – orchestration, validation, and comparison utilities.
- `workflow/` – convenience shell wrapper for running the scripted pipeline.
- `docs/` – setup, workflow, and validation references.
- `CoastSat/` – snapshot of original published data (`data/nzd0001/`) and supporting transects for validation.

## Setup

1. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
2. Configure GDAL if required for your platform.
3. Provide credentials:
   - Google Earth Engine service account and private key (`.private-key.json`).
   - NIWA Tide API key in `.env`.

Detailed setup notes are in `docs/setup.md`.

## Running the Workflow

The pipeline mirrors the original `update.sh` sequence:

```bash
./workflow/workflow.sh            # Full end-to-end run
python3 scripts/batch_process_NZ.py
python3 scripts/batch_process_sar.py
python3 scripts/tidal_correction.py --mode fetch
python3 scripts/slope_estimation.py
python3 scripts/tidal_correction.py --mode apply
python3 scripts/linear_models.py
python3 scripts/make_xlsx.py
```

Supplementary helpers:
- `python3 tests/run_full_workflow.py` – executes the staged steps in order.
- `python3 tests/validate_outputs.py` – checks for expected artefacts.

Workflow details live in `docs/workflow.md`.

## Validation

Original CoastSat outputs for `nzd0001` are stored under `CoastSat/data/`. Validation scripts re-run the minimal workflow with matching configuration and compare artefacts against those reference files.

Key commands:

```bash
./tests/validate_nzd0001.sh                 # Automated full comparison
python3 tests/validate_downstream.py --sites nzd0001   # Downstream-only check
python3 tests/compare_with_original.py --sites nzd0001 # Manual comparison
```

Known differences (for example the despike step) and interpretation guidance are documented in `docs/validation.md`.

## Next Steps

- Keep credentials out of version control (`.private-key.json`, `.env`).
- Use the validation scripts after substantive changes.
- Proceed with CWL componentisation once the repository layout and documentation meet project requirements.

