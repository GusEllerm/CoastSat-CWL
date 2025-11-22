# Results Directory

This directory contains workflow execution results and related files for the CoastSat-CWL project, which provides a CWL (Common Workflow Language) implementation of the [CoastSat](https://github.com/UoA-eResearch/CoastSat) workflow for automated shoreline change analysis.

## Running the Workflow

Execute the CWL workflow by running the `run_cwl.sh` script from this directory:

```bash
./run_cwl.sh
```

This script executes the `update_coastsat.cwl` workflow using cwltool with Docker containerization. The workflow automates the CoastSat processing pipeline, including:

- Downloading satellite imagery via Google Earth Engine
- Classifying images and detecting shorelines
- Calculating transect intersects
- Applying tidal corrections
- Computing linear trends

## Workflow Diagram

![Workflow Diagram](../workflow_diagram.svg)

## Input File Requirements

Before running the workflow, you must create an `input.yml` file in this directory. The input file should follow this structure:

### Data Inputs

- **`polygons_geojson`**: GeoJSON file containing polygon boundaries for the sites to process
- **`shoreline_geojson`**: GeoJSON file containing initial shoreline data
- **`transects_extended_geojson`**: GeoJSON file containing extended transect definitions
- **`transect_time_series_per_site`**: Directory containing the results from the previous workflow run. This directory should contain subdirectories for each site (e.g., `nzd0001/`, `sar0001/`) with time series CSV files from previous executions.

### Credential Inputs

- **`gee_key_json`**: Google Earth Engine service account JSON credentials (as a YAML multiline string)
- **`niwa_tide_api_key`**: API key for the NIWA Tide API used for tidal corrections

Example structure:

```yaml
# Data inputs
polygons_geojson:
  class: File
  path: /path/to/polygons.geojson
shoreline_geojson:
  class: File
  path: /path/to/shorelines.geojson
transects_extended_geojson:
  class: File
  path: /path/to/transects_extended.geojson
transect_time_series_per_site:
  class: Directory
  path: /path/to/previous/results/directory

# Credential inputs
gee_key_json: |
  {
    "type": "service_account",
    ...
  }
niwa_tide_api_key: "your-api-key"
```

**Important**: The `transect_time_series_per_site` directory should point to the output directory from a previous workflow execution. For iterative runs, this allows the workflow to build upon existing time series data.

## CWL Definitions

- **Workflows**: `../CoastSat-CWL/workflow/` - Contains workflow definitions including `update_coastsat.cwl`
- **Tools**: `../CoastSat-CWL/tools/` - Contains individual CWL tool definitions for each processing step

## Files

- `run_cwl.sh` - Script to execute the CWL workflow
- `input.yml` - Workflow input parameters (create this file before running)
- Other output files - Generated during workflow execution (not tracked in git)
