#!/usr/bin/env cwl-runner
# CWL tool for creating Excel reports from CoastSat outputs
# Converts CSV data and transects into Excel format with multiple sheets
cwlVersion: v1.2

class: CommandLineTool

baseCommand: python3

inputs:
  script:
    type: File
    default:
      class: File
      path: make_xlsx_wrapper.py
    inputBinding:
      position: 0
    doc: "Python wrapper script"
  
  transects_extended:
    type: File
    inputBinding:
      prefix: --transects
    doc: "GeoJSON file containing transect definitions (transects_extended.geojson)"
  
  transect_time_series_tidally_corrected:
    type: File
    inputBinding:
      prefix: --time-series
    doc: "CSV file with tidally corrected transect time series data"
  
  tides:
    type: File
    inputBinding:
      prefix: --tides
    doc: "CSV file with tide data for the site"
  
  site_id:
    type: string
    inputBinding:
      prefix: --site-id
    doc: "Site ID (e.g., nzd0001)"

outputs:
  excel_file:
    type: File
    outputBinding:
      glob: "$(inputs.site_id).xlsx"
    doc: "Excel file with multiple sheets containing intersects, tides, transects, and intersect points"

requirements:
  DockerRequirement:
    dockerImageId: coastsat-cwl:latest
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.script)
        entryname: make_xlsx_wrapper.py

stdout: excel_output.txt

