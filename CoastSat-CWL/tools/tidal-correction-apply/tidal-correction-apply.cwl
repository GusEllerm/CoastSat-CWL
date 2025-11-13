#!/usr/bin/env cwl-runner
# CWL tool for applying tidal correction to transect time series
# Applies tidal corrections using beach slopes from transects
cwlVersion: v1.2

class: CommandLineTool

baseCommand: [python3, tidal_correction_apply_wrapper.py]

inputs:
  script:
    type: File?
    default:
      class: File
      path: tidal_correction_apply_wrapper.py
    doc: "Python wrapper script (automatically staged via InitialWorkDirRequirement)"
  
  transect_time_series:
    type: File
    inputBinding:
      prefix: --transect-time-series
    doc: "CSV file with raw transect time series data (transect_time_series.csv)"
  
  tides:
    type: File
    inputBinding:
      prefix: --tides
    doc: "CSV file with tide data (tides.csv)"
  
  transects_extended:
    type: File
    inputBinding:
      prefix: --transects-extended
    doc: "GeoJSON file containing transect definitions with beach slopes (transects_extended.geojson)"
  
  site_id:
    type: string
    inputBinding:
      prefix: --site-id
    doc: "Site ID (e.g., nzd0001)"

outputs:
  tidally_corrected_csv:
    type: File
    outputBinding:
      glob: "$(inputs.site_id)_transect_time_series_tidally_corrected.csv"
    doc: "CSV file with tidally corrected transect time series data"

requirements:
  DockerRequirement:
    dockerImageId: coastsat-cwl:latest
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.script)
        entryname: tidal_correction_apply_wrapper.py

stdout: tidal_correction_apply_output.txt

