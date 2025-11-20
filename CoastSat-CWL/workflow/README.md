## CoastSat-CWL Workflows

This directory contains CWL workflow definitions that orchestrate the tools in `../tools` to run end-to-end CoastSat processing.

- **`example_scatter.cwl`**: Example CWL workflow demonstrating a simple scatter-style processing pattern using CoastSat tools.
- **`load_credentials_workflow.cwl`**: Workflow to load and prepare credentials (e.g. Google Earth Engine secrets) for use by other workflows.
- **`prepare_workflow_sites.cwl`**: Workflow to prepare site lists and related inputs before running main CoastSat processing.
- **`update_coastsat.cwl`**: Main CoastSat update workflow that chains together the tools to process sites and update coastal metrics.


