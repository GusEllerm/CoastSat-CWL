# CoastSat-CWL

Common Workflow Language (CWL) components for the CoastSat coastal shoreline processing pipeline.

## Status

🚧 **Under Development** – CWL components are being developed to replicate the functionality of `CoastSat-minimal/`.

## Overview

This directory will contain CWL workflow definitions that enable portable, reproducible execution of the CoastSat pipeline across different workflow engines (e.g., cwltool, Toil, Arvados, Cromwell).

## Components

CWL components will be organized by processing step:

- **Download** – Satellite imagery download from Google Earth Engine
- **Preprocessing** – Image preprocessing and enhancement
- **Shoreline Extraction** – Automated shoreline detection
- **Tidal Correction** – Tide data fetching and correction
- **Slope Estimation** – Beach slope calculation
- **Linear Models** – Trend analysis and modeling
- **Reporting** – Excel report generation

## Reference Implementation

The reference implementation can be found in [`../CoastSat-minimal/`](../CoastSat-minimal/), which provides the functional baseline for CWL component development.

