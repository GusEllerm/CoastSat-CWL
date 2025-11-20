#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  Workflow to extract nzd and sar site lists from polygons.geojson
  and make them available as string[] arrays for subsequent processing steps.

label: Prepare Workflow Sites

requirements:
  - class: InlineJavascriptRequirement

inputs:
  polygons_geojson:
    type: File
    doc: GeoJSON file containing polygon features with site IDs

outputs: 
  nzd_list:
    type: string[]
    outputSource: get_nzd_sar/nzd_list
    doc: List of NZD site IDs ready for handoff to subsequent steps
  
  sar_list:
    type: string[]
    outputSource: get_nzd_sar/sar_list
    doc: List of SAR site IDs ready for handoff to subsequent steps

steps:
  group_ids:
    run: ../tools/group_by_prefix/group_by_prefix.cwl
    in:
      polygons_geojson: polygons_geojson
    out: [grouped_ids]
  
  read_array_file:
    run: ../tools/group_by_prefix/read_grouped_ids_array.cwl
    in:
      grouped_ids_json: group_ids/grouped_ids
    out: [grouped_ids_array_file]
  
  read_array:
    run: ../tools/group_by_prefix/read_grouped_ids_array_expr.cwl
    in:
      grouped_ids_array_file: read_array_file/grouped_ids_array_file
    out: [grouped_ids_array]
  
  get_nzd_sar:
    run: ../tools/group_by_prefix/get_nzd_sar_lists.cwl
    in:
      grouped_ids_array: read_array/grouped_ids_array
    out: [nzd_list, sar_list]