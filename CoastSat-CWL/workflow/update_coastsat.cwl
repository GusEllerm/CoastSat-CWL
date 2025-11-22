#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow
$namespaces:
  cwltool: "http://commonwl.org/cwltool#"
hints:
  "cwltool:Secrets":
    secrets: [gee_key_json, niwa_tide_api_key]

doc: |
  Example workflow demonstrating parallel processing with scatter-gather.
  
  This workflow:
  1. Prepares site lists (nzd_list, sar_list) using prepare_workflow_sites
  2. Processes each site ID in parallel using scatter
  3. Collects all results before proceeding
  
  The scatter pattern allows:
  - Parallel processing of nzd_list and sar_list (separate scatter steps)
  - Parallel processing of each site within each list
  - Automatic collection/waiting for all processes to complete

label: Example Parent Workflow with Parallel Processing

requirements:
  - class: InlineJavascriptRequirement
  - class: SubworkflowFeatureRequirement
  - class: ScatterFeatureRequirement
  - class: MultipleInputFeatureRequirement

inputs:
  # Slope estimation extension for the CoastSat tool.
  sds_slope:
    type: File
    loadContents: true
    default:
      class: File
      location: ../tools/slope_estimation_site/SDS_slope.py

  # Data inputs
  polygons_geojson:
    type: File
    doc: GeoJSON file containing polygon features with site IDs
  shoreline_geojson:
    type: File
    doc: GeoJSON file containing shoreline features with site IDs
  transects_extended_geojson:
    type: File
    doc: GeoJSON file containing transects features with site IDs
  transect_time_series_per_site:
    type: Directory
    doc: Directory conatining the existing data for each of these sites. 
  
 # Credential files 
  gee_key_json:
    type: string
    doc: |
      Full GEE service account JSON as a string.
      (e.g., the contents of your key file)
  niwa_tide_api_key:
    type: string
    doc: |
      NIWA tide API key as a plain string.


outputs:

  # Primary results
  nzd_results:
      type: Directory[]
      outputSource: make_xlsx_nzd/site_dir
      doc: |
        Per-site directories each containing transect_time_series.csv, tides.csv, and transect_time_series_tidally_corrected.csv.
  sar_results:
    type: Directory[]
    outputSource: clean_sar_sites/site_dir
    doc: |
      Per-site directories each containing transect_time_series.csv, tides.csv, and transect_time_series_tidally_corrected.csv.
  transects_extended:
    type: File
    outputSource: merge_linear_models/transects_extended_geojson_out
    doc: |
      The final transect_extended data with linear regression estimations
  transects_summary:
    type: File
    outputSource: make_transects_summary/transects_xlsx
    doc: |
      The global transects summary in Excel format.

  # Credentials summary for debugging
  credentials_summary:
      type: File
      outputSource: load_creds/credentials_summary
      doc: |
        Simple text summary confirming that secrets were loaded and env vars set.

  # Optional outputs to capture intermediate satelite imagry
  # sar_sat_images:
  #   type: Directory[]
  #   outputSource: process_sar_sites/site_dir
  #   doc: |
  #     Per-site directories each containing the satellite imagery for the site.
  # nzd_sat_images:
  #   type: Directory[]
  #   outputSource: process_nzd_sites/site_dir
  #   doc: |
  #     Per-site directories each containing the satellite imagery for the site.
steps:

  # Step 1: Load credentials
  # This handles both GEE and environment variable loading
  load_creds:
    run: ../tools/use_gee_secrets/use_gee_secrets.cwl
    in: 
      gee_key_json: gee_key_json
      niwa_tide_api_key: niwa_tide_api_key
    out: [credentials_summary]

  # Step 2: Prepare site lists
  prepare_sites:
    run: prepare_workflow_sites.cwl
    in:
      polygons_geojson: polygons_geojson
    out: [nzd_list, sar_list]
  
  # Step 3: Process NZD sites in parallel
  # scatter: runs this step once for each item in nzd_list
  # All processes run in parallel automatically
  # If you want access to the sat data, output site_dir from this step.
  process_nzd_sites:
    run: ../tools/batch_process_nz/batch_process_nz.cwl
    scatter: site_id
    scatterMethod: dotproduct
    in:
      site_id: prepare_sites/nzd_list
      polygons_geojson: polygons_geojson
      shoreline_geojson: shoreline_geojson
      transects_extended_geojson: transects_extended_geojson
      transect_time_series_per_site: transect_time_series_per_site
      gee_key_json: gee_key_json
    out: [transect_time_series, site_dir]
    doc: |
      Processes each NZD site ID in parallel using the batch_process_nz tool.
      Each scattered run produces a transect_time_series.csv file for that site.

  
  # Step 4: Process SAR sites in parallel
  # This runs in parallel with process_nzd_sites (different step)
  # Within this step, each SAR site is also processed in parallel
  # If you want access to the sat data, output site_dir from this step.
  process_sar_sites:
    run: ../tools/batch_process_sar/batch_process_sar.cwl
    scatter: site_id
    scatterMethod: dotproduct
    in:
      site_id: prepare_sites/sar_list
      polygons_geojson: polygons_geojson
      shoreline_geojson: shoreline_geojson
      transects_extended_geojson: transects_extended_geojson
      transect_time_series_per_site: transect_time_series_per_site
      gee_key_json: gee_key_json
    out: [transect_time_series, site_dir]
    doc: |
      Processes each SAR site ID in parallel using the batch_process_sar tool.
      Each scattered run produces a per-site directory containing transect_time_series.csv.

  # Step 5: Fetch NZD tides
  # This step fetches tides.csv for each NZD site using the NIWA API.
  fetch_nzd_tides:
    run: ../tools/fetch_tides_nz_site/fetch_tides_nz_site.cwl
    scatter: [site_id, site_dir_in]
    scatterMethod: dotproduct
    in:
      site_id: prepare_sites/nzd_list
      polygons_geojson: polygons_geojson
      site_dir_in: process_nzd_sites/site_dir
      existing_root: transect_time_series_per_site
      niwa_tide_api_key: niwa_tide_api_key
    out: [site_dir, tides_csv]
    doc: |
      Fetches (or completes) tides.csv for each NZD site using the NIWA API.
      Produces per-site directories containing transect_time_series.csv and tides.csv.


  # Step 6: per-site slope estimation (scattered)
  slope_estimation_site:
    run: ../tools/slope_estimation_site/slope_estimation_site.cwl
    scatter: [site_id, site_dir]
    scatterMethod: dotproduct
    in:
      site_id: prepare_sites/nzd_list
      site_dir: fetch_nzd_tides/site_dir
      transects_extended_geojson: transects_extended_geojson
      sds_slope: sds_slope
    out: [site_slopes]

  # Step 7: merge slopes into a single transects_extended.geojson
  merge_slopes:
    run: ../tools/merge_slopes/merge_slopes.cwl
    in:
      transects_extended_geojson: transects_extended_geojson
      site_slopes: slope_estimation_site/site_slopes
    out: [transects_extended_geojson_out]

  # Step 8: Apply tidal correction to NZD sites
  apply_nzd_tidal_correction:
    run: ../tools/tidal_correction_nz/tidal_correction_nz.cwl
    scatter: [site_id, site_dir_in]
    scatterMethod: dotproduct
    in:
      site_id: prepare_sites/nzd_list
      transects_extended_geojson: merge_slopes/transects_extended_geojson_out
      site_dir_in: fetch_nzd_tides/site_dir
    out: [site_dir, transect_time_series_tidally_corrected]


  # Step 9: Linear models per NZD site (parallel)
  linear_models_nzd:
    run: ../tools/linear_models_site/linear_models_site.cwl
    scatter: [site_id, site_dir]
    scatterMethod: dotproduct
    in:
      site_id: prepare_sites/nzd_list
      site_dir: apply_nzd_tidal_correction/site_dir
    out: [site_models]

  # Step 10: Linear models per SAR site (parallel)
  linear_models_sar:
    run: ../tools/linear_models_site/linear_models_site.cwl
    scatter: [site_id, site_dir]
    scatterMethod: dotproduct
    in:
      site_id: prepare_sites/sar_list
      site_dir: process_sar_sites/site_dir
    out: [site_models, site_dir]

  # Step 11: Trim SAR site directories to remove imagery
  clean_sar_sites:
    run: ../tools/clean_sar_site_dir/clean_sar_site_dir.cwl
    scatter: [site_id, src_dir]
    scatterMethod: dotproduct
    in:
      site_id: prepare_sites/sar_list
      src_dir: linear_models_sar/site_dir
    out: [site_dir]

  # Step 12: Merge linear results into transects_extended.geojson
  merge_linear_models:
    run: ../tools/merge_linear_models/merge_linear_models.cwl
    in:
      transects_extended_geojson: merge_slopes/transects_extended_geojson_out
      site_models:
        source:
          - linear_models_nzd/site_models
          - linear_models_sar/site_models
        linkMerge: merge_flattened
    out: [transects_extended_geojson_out]

  # Steps 13 and 14 are optional, and create summarisations of NZ sites. 
  # Step 13: global transects summary
  make_transects_summary:
    run: ../tools/make_transects_summary/make_transects_summary.cwl
    in:
      transects_extended_geojson: merge_linear_models/transects_extended_geojson_out
    out: [transects_xlsx]

  # Step 14: Excel per NZD site (parallel)
  make_xlsx_nzd:
    run: ../tools/make_xlsx_site/make_xlsx_site.cwl
    scatter: [site_id, site_dir]
    scatterMethod: dotproduct
    in:
      site_id: prepare_sites/nzd_list
      site_dir: apply_nzd_tidal_correction/site_dir
      transects_extended_geojson: merge_linear_models/transects_extended_geojson_out
    out: [site_xlsx, site_dir]
