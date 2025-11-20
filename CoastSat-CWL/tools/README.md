## CoastSat-CWL Tools

This directory contains CWL tool definitions (and a few helper scripts) used by the CoastSat-CWL workflows.

- **`batch_process_nz/`**: CWL tool and Python script to batch-process New Zealand CoastSat sites.
- **`batch_process_sar/`**: CWL tool for batch-processing SAR (synthetic aperture radar) inputs.
- **`collect_results/`**: CWL tool for collecting and aggregating workflow outputs.
- **`fetch_tides_nz_site/`**: CWL tool to fetch tidal information for a New Zealand site.
- **`group_by_prefix/`**: CWL tools for grouping input IDs by prefix and reading grouped ID arrays (see this subdirectory’s `README.md` for details).
- **`linear_models_site/`**: CWL tool to fit/apply linear models for a single site.
- **`make_transects_summary/`**: CWL tool to generate summary products for transects.
- **`make_xlsx_site/`**: CWL tool to create Excel (`.xlsx`) outputs for a site.
- **`merge_linear_models/`**: CWL tool to merge site-level linear model results.
- **`merge_slopes/`**: CWL tool to merge shoreline slope estimates across sites or transects.
- **`process_site/`**: CWL tool to run the core CoastSat processing for a single site.
- **`slope_estimation_site/`**: CWL tool (with helper script `SDS_slope.py`) for estimating shoreline slopes at a site.
- **`tidal_correction_nz/`**: CWL tool to apply tidal corrections for New Zealand sites.
- **`use_gee_secrets/`**: CWL tool for accessing Google Earth Engine credentials/secrets within workflows.


