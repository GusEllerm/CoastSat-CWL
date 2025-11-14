# CoastSat CWL Workflows

This directory contains CWL workflow definitions that orchestrate the CoastSat processing pipeline.

## Workflows

### `coastsat-workflow.cwl`

The main workflow that orchestrates all CoastSat processing steps:

1. **Batch Process NZ Sites** (parallel scatter)
2. **Batch Process SAR Sites** (parallel scatter, optional)
3. **Fetch Tides** (parallel scatter for NZ and SAR sites separately)
4. **Slope Estimation** (parallel scatter for NZ and SAR sites separately)
5. **Aggregate Slope Outputs** (merge per-site transects into single file)
6. **Apply Tidal Correction** (parallel scatter for NZ and SAR sites separately)
7. **Linear Models** (parallel scatter for NZ and SAR sites separately)
8. **Aggregate Linear Model Outputs** (merge per-site transects into single file)
9. **Generate Excel Reports** (parallel scatter for NZ and SAR sites separately)

**Note**: The workflow is currently being developed. Type alignment issues with scatter steps need to be resolved.

## Workflow Inputs

- `polygons`: GeoJSON file with polygon definitions
- `shorelines`: GeoJSON file with reference shoreline definitions
- `transects_extended`: GeoJSON file with transect definitions
- `nz_sites`: Array of NZ site IDs (e.g., `['nzd0001', 'nzd0002']`)
- `sar_sites`: Array of SAR site IDs (e.g., `['sar0001']`)
- `output_dir`: Output directory for all outputs
- `start_date`: Start date for image download (YYYY-MM-DD)
- `end_date`: End date for image download (YYYY-MM-DD)
- `sat_list`: Array of satellite names (e.g., `['L8', 'L9']`)
- `gee_service_account`: GEE service account email (optional)
- `gee_private_key`: GEE private key file (optional)
- `niwa_api_key`: NIWA API key (optional)
- `sds_slope_module`: SDS_slope.py module file

## Workflow Outputs

- `final_transects_extended`: Aggregated transects GeoJSON with all updates
- `excel_reports`: Excel report files for NZ sites
- `excel_reports_sar`: Excel report files for SAR sites

## Usage

```bash
cwltool workflows/coastsat-workflow.cwl workflow-inputs.yml
```

## Current Status

⚠️ **Work in Progress**: The workflow has validation errors related to type alignment in scatter steps. These need to be resolved before execution.

The main challenge is ensuring proper alignment between array outputs from one scatter step and inputs to the next scatter step. This requires careful ordering of scatter fields.
