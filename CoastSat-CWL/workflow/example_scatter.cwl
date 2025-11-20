#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

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

inputs:
  polygons_geojson:
    type: File
    doc: GeoJSON file containing polygon features with site IDs


outputs:
  nzd_results:
    type: File[]
    outputSource: process_nzd_sites/result
    doc: Results from processing all NZD sites (collected array)
  
  sar_results:
    type: File[]
    outputSource: process_sar_sites/result
    doc: Results from processing all SAR sites (collected array)
  
  all_results:
    type: File[]
    outputSource: collect_all/results
    doc: All results combined from both NZD and SAR processing

steps:
  # Step 1: Prepare site lists
  prepare_sites:
    run: prepare_workflow_sites.cwl
    in:
      polygons_geojson: polygons_geojson
    out: [nzd_list, sar_list]
  
  # Step 2: Process NZD sites in parallel
  # scatter: runs this step once for each item in nzd_list
  # All processes run in parallel automatically
  process_nzd_sites:
    run: ../tools/process_site/process_site.cwl
    scatter: site_id
    scatterMethod: dotproduct
    in:
      site_id: prepare_sites/nzd_list
    out: [result]
    doc: |
      Processes each NZD site ID in parallel.
      The scatter directive causes this step to run once per item in nzd_list.
      All executions run concurrently.
  
  # Step 3: Process SAR sites in parallel
  # This runs in parallel with process_nzd_sites (different step)
  # Within this step, each SAR site is also processed in parallel
  process_sar_sites:
    run: ../tools/process_site/process_site.cwl
    scatter: site_id
    scatterMethod: dotproduct
    in:
      site_id: prepare_sites/sar_list
    out: [result]
    doc: |
      Processes each SAR site ID in parallel.
      This step runs concurrently with process_nzd_sites.
      Within this step, all SAR sites are processed in parallel.
  
  # Step 4: Collect all results
  # This step waits for both process_nzd_sites and process_sar_sites to complete
  # before executing (automatic dependency resolution)
  collect_all:
    run: ../tools/collect_results/collect_results.cwl
    in:
      nzd_results: process_nzd_sites/result
      sar_results: process_sar_sites/result
    out: [results]
    doc: |
      Collects and combines all results.
      This step automatically waits for all scattered processes to complete.
