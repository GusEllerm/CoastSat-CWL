#!/usr/bin/env cwl-runner
# CWL tool for batch processing SAR sites
# Downloads satellite imagery from Google Earth Engine and extracts shorelines for a single SAR site
cwlVersion: v1.2

class: CommandLineTool

baseCommand: [python3, batch_process_sar_wrapper.py]

inputs:
  script:
    type: File?
    default:
      class: File
      path: batch_process_sar_wrapper.py
    doc: "Python wrapper script (automatically staged via InitialWorkDirRequirement)"
  
  site_id:
    type: string
    inputBinding:
      prefix: --site-id
    doc: "Site ID (e.g., sar0001)"
  
  polygons:
    type: File
    inputBinding:
      prefix: --polygons
    doc: "GeoJSON file containing polygon definitions (polygons.geojson)"
  
  shorelines:
    type: File
    inputBinding:
      prefix: --shorelines
    doc: "GeoJSON file containing reference shoreline definitions (shorelines.geojson)"
  
  transects_extended:
    type: File
    inputBinding:
      prefix: --transects-extended
    doc: "GeoJSON file containing transect definitions (transects_extended.geojson)"
  
  output_dir:
    type: Directory
    inputBinding:
      prefix: --output-dir
    doc: "Output directory (will create data/{site_id}/ subdirectory)"
  
  start_date:
    type: string?
    default: "1900-01-01"
    inputBinding:
      prefix: --start-date
    doc: "Start date for image download (YYYY-MM-DD)"
  
  end_date:
    type: string?
    default: "2030-12-30"
    inputBinding:
      prefix: --end-date
    doc: "End date for image download (YYYY-MM-DD)"
  
  sat_list:
    type: string[]?
    inputBinding:
      prefix: --sat-list
      itemSeparator: " "
    doc: "Satellite list (e.g., ['L8', 'L9'])"
  
  gee_service_account:
    type: string?
    inputBinding:
      prefix: --gee-service-account
    doc: "Google Earth Engine service account email (or use GEE_SERVICE_ACCOUNT env var)"
  
  gee_private_key:
    type: File?
    inputBinding:
      prefix: --gee-private-key
    doc: "Path to GEE private key JSON file (or use GEE_PRIVATE_KEY_PATH env var)"

outputs:
  transect_time_series:
    type: File
    outputBinding:
      glob: "data/$(inputs.site_id)/transect_time_series.csv"
    doc: "CSV file with transect time series data"

requirements:
  DockerRequirement:
    dockerImageId: coastsat-cwl:latest
  NetworkAccess:
    networkAccess: true
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.script)
        entryname: batch_process_sar_wrapper.py

stdout: batch_process_sar_output.txt

