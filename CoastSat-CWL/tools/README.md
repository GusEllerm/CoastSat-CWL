# CWL Tools

This directory contains CWL tool definitions for the CoastSat workflow.

## Tools

### make-xlsx.cwl

Creates Excel reports from CoastSat outputs for a single site.

**Inputs:**
- `transects_extended`: GeoJSON file with transect definitions
- `transect_time_series_tidally_corrected`: CSV with tidally corrected time series
- `tides`: CSV with tide data
- `site_id`: Site ID (e.g., "nzd0001")

**Outputs:**
- `excel_file`: Excel file (`{site_id}.xlsx`) with multiple sheets:
  - Intersects: Transect intersection data
  - Tides: Tide data
  - Transects: Transect geometry and metadata
  - Intersect points: Computed geographic points

**Dependencies:**
- Uses Docker image: `coastsat-cwl:latest`
- Requires Python wrapper script: `make_xlsx_wrapper.py`

**Testing:**
```bash
cd CoastSat-CWL
./test/test_make_xlsx.sh
```

**Status:** ✅ Complete and tested

## Testing

Each tool should have:
1. A CWL tool definition (`.cwl` file)
2. A Python wrapper script (if needed)
3. A test input file (in `test/` directory)
4. A test script (in `test/` directory)

Test scripts should:
- Validate the CWL tool
- Run the tool with test inputs
- Verify outputs
- Compare with expected outputs if available
