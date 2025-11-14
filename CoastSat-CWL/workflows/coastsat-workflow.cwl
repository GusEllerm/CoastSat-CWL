#!/usr/bin/env cwl-runner
# CoastSat CWL Workflow
# Orchestrates the complete CoastSat processing pipeline
cwlVersion: v1.2

class: Workflow

requirements:
  ScatterFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}

inputs:
  # Input GeoJSON files
  polygons:
    type: File
    doc: "GeoJSON file containing polygon definitions (polygons.geojson)"
  
  shorelines:
    type: File
    doc: "GeoJSON file containing reference shoreline definitions (shorelines.geojson)"
  
  transects_extended:
    type: File
    doc: "GeoJSON file containing transect definitions (transects_extended.geojson)"
  
  # Site lists
  nz_sites:
    type: string[]
    default: []
    doc: "List of NZ site IDs to process (e.g., ['nzd0001', 'nzd0002'])"
  
  sar_sites:
    type: string[]
    default: []
    doc: "List of SAR site IDs to process (e.g., ['sar0001'])"
  
  # Date range parameters
  start_date:
    type: string?
    default: "1984-01-01"
    doc: "Start date for image download (YYYY-MM-DD)"
  
  end_date:
    type: string?
    default: "2030-12-30"
    doc: "End date for image download (YYYY-MM-DD)"
  
  sat_list:
    type: string[]?
    default: ["L5", "L7", "L8", "L9"]
    doc: "Satellite list (e.g., ['L8', 'L9'])"
  
  # Output directory
  output_dir:
    type: Directory
    doc: "Output directory for all workflow outputs"
  
  # Credentials (optional, can use env vars instead)
  gee_service_account:
    type: string?
    doc: "Google Earth Engine service account email (optional if GEE_SERVICE_ACCOUNT env var is set)"
  
  gee_private_key:
    type: File?
    doc: "Path to GEE private key JSON file (optional if GEE_PRIVATE_KEY_PATH env var is set)"
  
  niwa_api_key:
    type: string?
    doc: "NIWA Tide API key (optional if NIWA_TIDE_API_KEY env var is set)"
  
  # SDS_slope module (required for slope estimation)
  sds_slope_module:
    type: File
    doc: "SDS_slope module file for slope estimation"
  
  # Script files (optional, tools have defaults)
  batch_process_nz_script:
    type: File?
    doc: "Python wrapper script for batch-process-nz tool (optional, tool has default)"
  
  batch_process_sar_script:
    type: File?
    doc: "Python wrapper script for batch-process-sar tool (optional, tool has default)"

outputs:
  # Aggregated transects (final output)
  final_transects_extended:
    type: File
    outputSource: aggregate_linear_models/aggregated_transects
    doc: "Final transects_extended.geojson with all updates (slopes and trend statistics)"
  
  # Excel reports per site (NZ sites)
  excel_reports_nz:
    type: File[]
    outputSource: make_xlsx_reports_nz/excel_file
    doc: "Excel report files per site (NZ sites)"
  
  # Excel reports per site (SAR sites)
  excel_reports_sar:
    type: File[]
    outputSource: make_xlsx_reports_sar/excel_file
    doc: "Excel report files per site (SAR sites)"

steps:
  # Step 1: Batch process NZ sites (parallel)
  batch_process_nz:
    run: ../tools/batch-process-nz/batch-process-nz.cwl
    in:
      site_id: nz_sites
      script: batch_process_nz_script
      polygons: polygons
      shorelines: shorelines
      transects_extended: transects_extended
      output_dir: output_dir
      start_date: start_date
      end_date: end_date
      sat_list: sat_list
      gee_service_account: gee_service_account
      gee_private_key: gee_private_key
    out: [transect_time_series]
    scatter: site_id
    scatterMethod: dotproduct
  
  # Step 2: Batch process SAR sites (parallel, optional)
  # Note: Only runs if sar_sites is non-empty (controlled by workflow input)
  batch_process_sar:
    run: ../tools/batch-process-sar/batch-process-sar.cwl
    in:
      site_id: sar_sites
      script: batch_process_sar_script
      polygons: polygons
      shorelines: shorelines
      transects_extended: transects_extended
      output_dir: output_dir
      start_date: start_date
      end_date: end_date
      sat_list: sat_list
      gee_service_account: gee_service_account
      gee_private_key: gee_private_key
    out: [transect_time_series]
    scatter: site_id
    scatterMethod: dotproduct
  
  # Step 3: Fetch tides for NZ sites (parallel)
  # Note: CWL scatter automatically aligns arrays from previous scatter steps
  # by index when both steps scatter over the same field (site_id)
  fetch_tides_nz:
    run: ../tools/tidal-correction-fetch/tidal-correction-fetch.cwl
    in:
      site_id: nz_sites
      polygons: polygons
      transect_time_series: batch_process_nz/transect_time_series
      niwa_api_key: niwa_api_key
    out: [tides_csv]
    scatter: [site_id, transect_time_series]
    scatterMethod: dotproduct
  
  # Step 3b: Fetch tides for SAR sites (parallel)
  fetch_tides_sar:
    run: ../tools/tidal-correction-fetch/tidal-correction-fetch.cwl
    in:
      site_id: sar_sites
      polygons: polygons
      transect_time_series: batch_process_sar/transect_time_series
      niwa_api_key: niwa_api_key
    out: [tides_csv]
    scatter: [site_id, transect_time_series]
    scatterMethod: dotproduct
  
  # Step 4: Slope estimation for NZ sites (parallel)
  slope_estimation_nz:
    run: ../tools/slope-estimation/slope-estimation.cwl
    in:
      site_id: nz_sites
      transect_time_series: batch_process_nz/transect_time_series
      tides: fetch_tides_nz/tides_csv
      transects_extended: transects_extended
      sds_slope_module: sds_slope_module
    out: [updated_transects]
    scatter: [site_id, transect_time_series, tides]
    scatterMethod: dotproduct
  
  # Step 4b: Slope estimation for SAR sites (parallel)
  slope_estimation_sar:
    run: ../tools/slope-estimation/slope-estimation.cwl
    in:
      site_id: sar_sites
      transect_time_series: batch_process_sar/transect_time_series
      tides: fetch_tides_sar/tides_csv
      transects_extended: transects_extended
      sds_slope_module: sds_slope_module
    out: [updated_transects]
    scatter: [site_id, transect_time_series, tides]
    scatterMethod: dotproduct
  
  # Step 5: Aggregate slope outputs into single transects_extended.geojson
  aggregate_slope:
    run: ../tools/aggregate-transects/aggregate-transects.cwl
    in:
      base_transects: transects_extended
      per_site_transects:
        source:
          - slope_estimation_nz/updated_transects
          - slope_estimation_sar/updated_transects
        linkMerge: merge_flattened
      output:
        default: transects_extended_slopes.geojson
    out: [aggregated_transects]
  
  # Step 6: Apply tidal correction for NZ sites (parallel)
  tidal_correction_apply_nz:
    run: ../tools/tidal-correction-apply/tidal-correction-apply.cwl
    in:
      site_id: nz_sites
      transect_time_series: batch_process_nz/transect_time_series
      tides: fetch_tides_nz/tides_csv
      transects_extended:
        source: aggregate_slope/aggregated_transects
    out: [tidally_corrected_csv]
    scatter: [site_id, transect_time_series, tides]
    scatterMethod: dotproduct
  
  # Step 6b: Apply tidal correction for SAR sites (parallel)
  tidal_correction_apply_sar:
    run: ../tools/tidal-correction-apply/tidal-correction-apply.cwl
    in:
      site_id: sar_sites
      transect_time_series: batch_process_sar/transect_time_series
      tides: fetch_tides_sar/tides_csv
      transects_extended:
        source: aggregate_slope/aggregated_transects
    out: [tidally_corrected_csv]
    scatter: [site_id, transect_time_series, tides]
    scatterMethod: dotproduct
  
  # Step 7: Linear models for NZ sites (parallel)
  linear_models_nz:
    run: ../tools/linear-models/linear-models.cwl
    in:
      site_id: nz_sites
      transect_time_series: tidal_correction_apply_nz/tidally_corrected_csv
      transects_extended:
        source: aggregate_slope/aggregated_transects
    out: [updated_transects]
    scatter: [site_id, transect_time_series]
    scatterMethod: dotproduct
  
  # Step 7b: Linear models for SAR sites (parallel)
  linear_models_sar:
    run: ../tools/linear-models/linear-models.cwl
    in:
      site_id: sar_sites
      transect_time_series: tidal_correction_apply_sar/tidally_corrected_csv
      transects_extended:
        source: aggregate_slope/aggregated_transects
    out: [updated_transects]
    scatter: [site_id, transect_time_series]
    scatterMethod: dotproduct
  
  # Step 8: Aggregate linear model outputs into single transects_extended.geojson
  aggregate_linear_models:
    run: ../tools/aggregate-transects/aggregate-transects.cwl
    in:
      base_transects:
        source: aggregate_slope/aggregated_transects
      per_site_transects:
        source:
          - linear_models_nz/updated_transects
          - linear_models_sar/updated_transects
        linkMerge: merge_flattened
      output:
        default: transects_extended.geojson
    out: [aggregated_transects]
  
  # Step 9: Generate Excel reports for NZ sites (parallel)
  make_xlsx_reports_nz:
    run: ../tools/make-xlsx/make-xlsx.cwl
    in:
      site_id: nz_sites
      transects_extended:
        source: aggregate_linear_models/aggregated_transects
      transect_time_series_tidally_corrected: tidal_correction_apply_nz/tidally_corrected_csv
      tides: fetch_tides_nz/tides_csv
    out: [excel_file]
    scatter: [site_id, transect_time_series_tidally_corrected, tides]
    scatterMethod: dotproduct
  
  # Step 9b: Generate Excel reports for SAR sites (parallel)
  make_xlsx_reports_sar:
    run: ../tools/make-xlsx/make-xlsx.cwl
    in:
      site_id: sar_sites
      transects_extended:
        source: aggregate_linear_models/aggregated_transects
      transect_time_series_tidally_corrected: tidal_correction_apply_sar/tidally_corrected_csv
      tides: fetch_tides_sar/tides_csv
    out: [excel_file]
    scatter: [site_id, transect_time_series_tidally_corrected, tides]
    scatterMethod: dotproduct

