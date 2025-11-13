# Workflow Overview

The minimal CoastSat pipeline mirrors the original `update.sh` logic while limiting processing to a small set of representative sites. The steps below outline the required artefacts and the order of execution.

## Inputs

- `inputs/polygons.geojson` – shoreline extraction polygons for the filtered sites.
- `inputs/shorelines.geojson` – reference shorelines.
- `inputs/transects_extended.geojson` – transects with metadata (slopes, trends populated during processing).
- Environment configuration from `.env` (credentials, optional test mode range).

## Processing Steps

| Order | Script | Purpose |
|-------|--------|---------|
| 1 | `scripts/batch_process_NZ.py` | Download Landsat imagery for NZ sites, extract shorelines, produce `transect_time_series.csv`. |
| 2 | `scripts/batch_process_sar.py` | Same as above for SAR sites when required. |
| 3 | `scripts/tidal_correction.py --mode fetch` | Call the NIWA API and write `tides.csv`. |
| 4 | `scripts/slope_estimation.py` | Estimate beach slopes per transect, updating `inputs/transects_extended.geojson`. |
| 5 | `scripts/tidal_correction.py --mode apply` | Apply tidal corrections to generate `transect_time_series_tidally_corrected.csv`. |
| 6 | `scripts/linear_models.py` | Compute linear shoreline change metrics (trend, MAE, RMSE). |
| 7 | `scripts/make_xlsx.py` | Collate site outputs into `{site_id}.xlsx`. |

`workflow/workflow.sh` executes these scripts sequentially.

## Outputs

For each processed site (e.g. `nzd0001`):

- `data/{site}/transect_time_series.csv`
- `data/{site}/tides.csv`
- `data/{site}/transect_time_series_tidally_corrected.csv`
- `data/{site}/{site}.xlsx`

`inputs/transects_extended.geojson` is updated in place as slopes and trend statistics are calculated.

## Helper Utilities

- `python3 tests/run_full_workflow.py` – scripted end-to-end runner with optional validation.
- `python3 tests/validate_outputs.py` – sanity checks that generated artefacts are present and readable.
- `python3 tests/validate_downstream.py --sites nzd0001` – reuses published transect data to re-run the downstream steps only.

## Test Mode

To limit processing for quick iteration, set the following in `.env`:

```env
TEST_MODE=true
TEST_START_DATE=2024-06-01
TEST_END_DATE=2024-12-31
TEST_SITES=nzd0001
TEST_SATELLITES=L8,L9
```

When `TEST_MODE` is false, the scripts default to full historical coverage (1999 onward for Landsat).

