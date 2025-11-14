#!/usr/bin/env cwl-runner
# CWL tool for fetching tide data from NIWA API
# Fetches tide data for a single site based on dates in transect time series
cwlVersion: v1.2

class: CommandLineTool

baseCommand: [python3, tidal_correction_fetch_wrapper.py]

inputs:
  script:
    type: File?
    default:
      class: File
      path: tidal_correction_fetch_wrapper.py
    doc: "Python wrapper script (automatically staged via InitialWorkDirRequirement)"
  
  polygons:
    type: File
    inputBinding:
      prefix: --polygons
    doc: "GeoJSON file containing polygon definitions (polygons.geojson)"
  
  transect_time_series:
    type: File
    inputBinding:
      prefix: --transect-time-series
    doc: "CSV file with transect time series data (contains dates to fetch tides for)"
  
  site_id:
    type: string
    inputBinding:
      prefix: --site-id
    doc: "Site ID (e.g., nzd0001)"
  
  niwa_api_key:
    type: string?
    inputBinding:
      prefix: --api-key
    doc: "NIWA Tide API key (optional if NIWA_TIDE_API_KEY env var is set)"

outputs:
  tides_csv:
    type: File
    outputBinding:
      glob: "$(inputs.site_id)_tides.csv"
    doc: "CSV file with tide data (dates, tide) for the site"

requirements:
  DockerRequirement:
    dockerImageId: coastsat-cwl:latest
  NetworkAccess:
    networkAccess: true
  # Environment variables are read from host environment via --preserve-environment flag
  # Tools check for NIWA_TIDE_API_KEY environment variable
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.script)
        entryname: tidal_correction_fetch_wrapper.py

stdout: tide_output.txt

