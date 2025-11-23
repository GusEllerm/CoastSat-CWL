# CoastSat-CWL

A [Common Workflow Language (CWL)](https://www.commonwl.org/) implementation of the [CoastSat](https://github.com/UoA-eResearch/CoastSat) automated shoreline monitoring workflow. This repository provides containerized, reproducible workflows for processing satellite imagery to track coastal shoreline changes over time.

## Overview

CoastSat-CWL converts the original Python-based CoastSat processing pipeline into modular CWL workflows and tools, enabling:

- **Reproducible execution** via containerized workflows
- **Parallel processing** of multiple coastal sites
- **Incremental data updates** that build upon previous results
- **Automated processing** of satellite imagery from Google Earth Engine
- **Tidal corrections** for New Zealand sites using the NIWA Tide API
- **Statistical analysis** including beach slope estimation and linear trend modeling

## Workflow Diagram

![CoastSat-CWL Workflow Diagram](workflow_diagram.svg)

## Key Components

- **`CoastSat-CWL/`**: Main CWL workflow and tool definitions

  - `workflow/`: Workflow definitions including `update_coastsat.cwl` (main workflow)
  - `tools/`: Individual CWL tool definitions for each processing step
  - `Dockerfile`: Container image with CoastSat dependencies
  - `environment.yml`: Conda environment specification
  - `data/`: Input and output data directories
  - `tests/`: Test input files and examples (see `tests/README.md` for usage)
- **`workflow_diagram.svg`**: Visual diagram of the workflow structure and data flow

## Quick Start

1. Create an `input.yml` file with your workflow parameters (see `CoastSat-CWL/tests/workflow/` for example input files)
2. Run the workflow using `cwltool`:
   ```bash
   cwltool --enable-ext --parallel \
     CoastSat-CWL/workflow/update_coastsat.cwl \
     input.yml
   ```

   Or using Docker:
   ```bash
   docker run --rm \
     -v $(pwd):/workspace \
     -w /workspace \
     gusellerm/coastsat-cwl:latest \
     cwltool --enable-ext --parallel \
       CoastSat-CWL/workflow/update_coastsat.cwl \
       input.yml
   ```

The workflow processes satellite imagery, extracts shorelines, applies corrections, and generates time series data and statistical summaries.

For detailed examples, see `CoastSat-CWL/tests/README.md`.

## Workflow Features

The main `update_coastsat.cwl` workflow orchestrates:

- **Site preparation**: Organizes input sites (NZD for New Zealand, SAR for Sardinia)
- **Batch processing**: Downloads and processes satellite imagery from Google Earth Engine
- **Tidal correction**: Applies tidal corrections for New Zealand sites
- **Slope estimation**: Estimates beach slopes for transects
- **Linear modeling**: Calculates shoreline change trends and statistics
- **Output generation**: Produces Excel summaries and GeoJSON files with updated metrics

## Docker Container

The workflow is designed to run using the pre-built Docker image [`gusellerm/coastsat-cwl:latest`](https://hub.docker.com/repository/docker/gusellerm/coastsat-cwl/general), which bundles the complete execution environment including:

- Python 3.11 with scientific stack (NumPy, SciPy, scikit-learn, GDAL, GeoPandas, etc.)
- CoastSat package and processing scripts
- cwltool for workflow execution
- Full CoastSat-CWL repository with workflows and tools

Mount your data, configuration, and output directories as volumes:

```bash
docker run --rm \
  -v /path/to/data:/data \
  -v /path/to/cfg:/cfg \
  -v /path/to/out:/out \
  gusellerm/coastsat-cwl:latest \
  bash -lc 'cwltool --enable-ext --parallel --outdir /out \
    /CoastSat-CWL/workflow/update_coastsat.cwl \
    /cfg/input.yml'
```

Your input YAML should reference paths within `/data` (e.g., `/data/input/polygons.geojson`). All outputs are written to `/out`.

## Requirements

- **cwltool**: CWL workflow execution engine (install via `pip install cwltool` or use Docker)
- **Docker** (optional, for containerized execution)
- **Google Earth Engine service account credentials**: See `CoastSat-CWL/tools/CREDENTIALS.md` for details
- **NIWA Tide API key** (for New Zealand sites): See `CoastSat-CWL/tools/CREDENTIALS.md` for details
- **Network access** to Google Earth Engine and NIWA API

See `CoastSat-CWL/Dockerfile` and `CoastSat-CWL/environment.yml` for dependency details.
