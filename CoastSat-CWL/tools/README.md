# CWL Tools

This directory contains CWL CommandLineTool definitions for each step of the CoastSat workflow.

## Tool Definitions

- `batch-process-nz.cwl` - Batch process NZ sites
- `batch-process-sar.cwl` - Batch process SAR sites
- `tidal-correction-fetch.cwl` - Fetch tide data from NIWA API
- `tidal-correction-apply.cwl` - Apply tidal corrections
- `slope-estimation.cwl` - Estimate beach slopes
- `linear-models.cwl` - Compute linear shoreline change metrics
- `make-xlsx.cwl` - Generate Excel reports

## Tool Structure

Each tool definition includes:
- Input declarations
- Output declarations
- Docker requirement (base image)
- Base command and arguments
- Environment variable handling

## Testing Individual Tools

```bash
cwltool tools/batch-process-nz.cwl tool-input.yml
```

## Dependencies

All tools use the base Docker image defined in `../docker/Dockerfile`.

