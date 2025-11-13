# CWL Workflows

This directory contains CWL workflow definitions that orchestrate the CoastSat processing pipeline.

## Main Workflow

- `coastsat-workflow.cwl` - Full end-to-end workflow for all sites
- `coastsat-workflow-test.cwl` - Test version with limited date range and sites

## Workflow Structure

The main workflow orchestrates the following steps:

1. Batch processing (NZ and SAR sites)
2. Tidal correction (fetch)
3. Slope estimation
4. Tidal correction (apply)
5. Linear models
6. Report generation

## Usage

```bash
cwltool workflows/coastsat-workflow.cwl workflow-input.yml
```

## Input Format

See `../examples/workflow-input.yml` for an example input file.

## Provenance

Run with CWLProv to generate provenance records:

```bash
cwlprov run workflows/coastsat-workflow.cwl workflow-input.yml
```

