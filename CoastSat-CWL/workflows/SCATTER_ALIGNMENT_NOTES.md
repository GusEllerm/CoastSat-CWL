# Scatter Alignment Notes

## The Issue

When you scatter a step, its outputs become arrays (e.g., `File[]`). When you use those arrays as inputs to another step that also scatters, CWL needs to align the arrays by index.

## Expected Behavior

In CWL scatter with `scatterMethod: dotproduct`:
- When Step A scatters over `site_id: ["nzd0001", "nzd0002"]` and outputs `transect_time_series: [File1, File2]`
- When Step B also scatters over `site_id: ["nzd0001", "nzd0002"]` and uses `transect_time_series` from Step A
- CWL automatically extracts `File1` for iteration 0 (with `site_id: "nzd0001"`) and `File2` for iteration 1 (with `site_id: "nzd0002"`)

This is the expected behavior and works correctly at runtime.

## Validation Warnings

The `cwltool` validator may show type incompatibility warnings because:
- It checks types before considering scatter context
- It sees `File[]` (array) where `File` (single) is expected
- It can't verify at validation time that arrays will align correctly

## Solution

These validation warnings are expected and can be safely ignored when:
1. All scatter steps use the same scatter field (e.g., `site_id: nz_sites`)
2. The arrays come from previous scatter steps using the same scatter field
3. The arrays are guaranteed to have the same length and order

At runtime, CWL handles the alignment correctly.

## Current Workflow Structure

Our workflow uses separate steps for NZ and SAR sites to ensure proper alignment:
- `batch_process_nz` scatters over `nz_sites` → outputs `File[]`
- `fetch_tides_nz` scatters over `nz_sites` → uses `File[]` from `batch_process_nz`
- CWL automatically aligns them by index (position 0 with position 0, etc.)

This structure ensures correct runtime behavior even if the validator shows warnings.

