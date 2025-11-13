#!/usr/bin/env cwl-runner
# CWL tool for estimating beach slopes using spectral analysis
# Estimates beach slopes for transects at a single site
cwlVersion: v1.2

class: CommandLineTool

baseCommand: [python3, slope_estimation_wrapper.py]

inputs:
  script:
    type: File?
    default:
      class: File
      path: slope_estimation_wrapper.py
    doc: "Python wrapper script (automatically staged via InitialWorkDirRequirement)"
  
  sds_slope_module:
    type: File
    default:
      class: File
      path: ../../../CoastSat-minimal/scripts/SDS_slope.py
    doc: "SDS_slope module file (required dependency)"
  
  transect_time_series:
    type: File
    inputBinding:
      prefix: --transect-time-series
    doc: "CSV file with transect time series data (transect_time_series.csv)"
  
  tides:
    type: File
    inputBinding:
      prefix: --tides
    doc: "CSV file with tide data (tides.csv)"
  
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
      glob: "$(inputs.site_id)_transects_updated.geojson"
    doc: "GeoJSON file with updated beach_slope values for transects at this site"

requirements:
  DockerRequirement:
    dockerImageId: coastsat-cwl:latest
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.script)
        entryname: slope_estimation_wrapper.py
      - entry: $(inputs.sds_slope_module)
        entryname: SDS_slope.py

stdout: slope_estimation_output.txt
