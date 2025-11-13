#!/usr/bin/env cwl-runner
# CWL tool for calculating linear trends for tidally corrected transect time series
# Calculates linear regression trends and statistics for transects at a single site
cwlVersion: v1.2

class: CommandLineTool

baseCommand: [python3, linear_models_wrapper.py]

inputs:
  script:
    type: File?
    default:
      class: File
      path: linear_models_wrapper.py
    doc: "Python wrapper script (automatically staged via InitialWorkDirRequirement)"
  
  transect_time_series:
    type: File
    inputBinding:
      prefix: --transect-time-series
    doc: "CSV file with tidally corrected transect time series data (transect_time_series_tidally_corrected.csv)"
  
  transects_extended:
    type: File
    inputBinding:
      prefix: --transects-extended
    doc: "GeoJSON file containing transect definitions (transects_extended.geojson)"
  
  site_id:
    type: string
    inputBinding:
      prefix: --site-id
    doc: "Site ID (e.g., nzd0001)"

outputs:
  updated_transects:
    type: File
    outputBinding:
      glob: "$(inputs.site_id)_transects_with_trends.geojson"
    doc: "GeoJSON file with updated trend statistics for transects at this site"

requirements:
  DockerRequirement:
    dockerImageId: coastsat-cwl:latest
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.script)
        entryname: linear_models_wrapper.py

stdout: linear_models_output.txt

