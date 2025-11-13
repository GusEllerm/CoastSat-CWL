# Validation Guide

This project retains a snapshot of the original CoastSat outputs for `nzd0001` under `CoastSat/data/`. Validation compares artefacts from the minimal workflow against those reference files to ensure behaviour remains aligned with the published results.

## Reference Data

- `CoastSat/data/nzd0001/` – original transect time series, tide data, tidally corrected series, and Excel export.
- `CoastSat/transects_extended.geojson` – original transect metadata (slopes, trend statistics).

## Recommended Commands

1. **End-to-end validation** – extracts the original configuration, runs the minimal workflow, and compares artefacts:
   ```bash
   ./tests/validate_nzd0001.sh
   ```
2. **Downstream-only check** – reuses the published `transect_time_series.csv` and regenerates the downstream outputs:
   ```bash
   python3 tests/validate_downstream.py --sites nzd0001
   ```
3. **Manual comparison** – compare specific sites or adjust tolerance:
   ```bash
   python3 tests/compare_with_original.py --sites nzd0001
   python3 tests/compare_with_original.py --sites nzd0001 --tolerance 1e-5
   ```

All comparison reports are written to the project root (e.g. `validation_report_nzd0001.txt`).

## Known Differences

- The despike step (`SDS_transects.identify_outliers`) removes outliers per transect independently. Depending on the underlying library version, corrected distances can diverge by ~7–10 m mean (up to ~25 m). These deviations are expected and accepted for downstream analysis.
- Ensure the same beach slopes are used when comparing against the original outputs. The repository ships with the published `transects_extended.geojson` for this purpose.

## Checklist Before Comparison

- Test mode is disabled or configured to match the original date range.
- `CoastSat/data/nzd0001/` is present and contains the published CSV/XLSX artefacts.
- `.env` contains the required credentials.
- Any cached outputs under `data/nzd0001/` have been cleared if a clean run is required.

## Troubleshooting

| Symptom | Likely Cause | Action |
|---------|--------------|--------|
| Missing files in comparison report | Workflow failed or outputs cleaned mid-run | Rerun the workflow step that produces the missing artefact. |
| Large differences (>25 m) | Mismatched slopes or date ranges | Copy `CoastSat/transects_extended.geojson` into `inputs/` and rerun with the original configuration. |
| Tides missing | NIWA API key absent or invalid | Confirm `NIWA_TIDE_API_KEY` in `.env` and re-fetch tides. |

## Artefact Locations

- New workflow outputs: `data/{site}/`
- Original reference outputs: `CoastSat/data/nzd0001/`
- Validation reports: project root (e.g. `validation_report_nzd0001.txt`)
