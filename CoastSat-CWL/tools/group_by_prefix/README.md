# Group by Prefix Tools

Tools for grouping polygon IDs by prefix and extracting nzd and sar site lists for use in CWL workflows.

## Tools

1. **`group_by_prefix.cwl`** - Main CommandLineTool that groups IDs from a GeoJSON file by prefix
2. **`read_grouped_ids_array.cwl`** - ExpressionTool to convert JSON file to `string[][]` array
3. **`get_nzd_sar_lists.cwl`** - ExpressionTool to get nzd and sar lists as `string[]` arrays

## Usage

The `prepare_workflow_sites.cwl` workflow demonstrates the complete usage pattern:

```yaml
steps:
  group_ids:
    run: ../tools/group_by_prefix/group_by_prefix.cwl
    in:
      polygons_geojson: polygons.geojson
    out: [grouped_ids]
  
  read_array:
    run: ../tools/group_by_prefix/read_grouped_ids_array.cwl
    in:
      grouped_ids_json: group_ids/grouped_ids
    out: [grouped_ids_array]
  
  get_nzd_sar:
    run: ../tools/group_by_prefix/get_nzd_sar_lists.cwl
    in:
      grouped_ids_array: read_array/grouped_ids_array
    out: [nzd_list, sar_list]
```

The `nzd_list` and `sar_list` outputs are `string[]` arrays that can be directly passed to subsequent workflow steps without reading from disk.

## Extending for Additional Prefixes

To add more prefix lists (e.g., "aus"), edit `get_nzd_sar_lists.cwl` and add additional outputs following the same pattern as `nzd_list` and `sar_list`.

## How It Works

The `group_by_prefix` tool extracts the prefix (everything before the first digit) from each site ID:
- `"aus0001"` → prefix `"aus"`
- `"nzd0001"` → prefix `"nzd"`
- `"sar0001"` → prefix `"sar"`

IDs are grouped by prefix and sorted alphabetically by prefix name.
