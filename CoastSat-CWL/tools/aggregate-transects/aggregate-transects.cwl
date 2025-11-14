#!/usr/bin/env cwl-runner
# CWL tool for aggregating per-site transect GeoJSON files into a single transects_extended.geojson
# Used after slope-estimation and linear-models steps to merge per-site outputs
cwlVersion: v1.2

class: CommandLineTool

baseCommand: [python3, aggregate_transects_wrapper.py]

inputs:
  script:
    type: File?
    default:
      class: File
      path: aggregate_transects_wrapper.py
    doc: "Python wrapper script (automatically staged via InitialWorkDirRequirement)"
  
  base_transects:
    type: File
    inputBinding:
      prefix: --base-transects
    doc: "Base transects_extended.geojson file (contains all transects from all sites)"
  
  per_site_transects:
    type: File[]
    inputBinding:
      prefix: --per-site-transects
      itemSeparator: " "
    doc: "Array of per-site transect GeoJSON files to merge (e.g., from slope-estimation or linear-models)"
  
  output:
    type: string
    default: "transects_extended.geojson"
    inputBinding:
      prefix: --output
    doc: "Output filename for aggregated transects_extended.geojson (default: transects_extended.geojson)"
  
  update_columns:
    type: string[]?
    inputBinding:
      prefix: --update-columns
      itemSeparator: " "
    doc: "Optional list of column names to update (default: all numeric columns)"

outputs:
  aggregated_transects:
    type: File
    outputBinding:
      glob: "$(inputs.output)"
    doc: "Aggregated transects_extended.geojson file with updated values from per-site files"

requirements:
  DockerRequirement:
    dockerImageId: coastsat-cwl:latest
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.script)
        entryname: aggregate_transects_wrapper.py

stdout: aggregate_transects_output.txt

