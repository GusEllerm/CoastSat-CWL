#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

doc: |
  Example tool that processes a single site ID.
  This is a placeholder - replace with your actual processing tool.

label: Process Single Site

inputs:
  site_id:
    type: string
    doc: The site ID to process (e.g., "nzd0001", "sar0001")

outputs:
  result:
    type: File
    outputBinding:
      glob: "result_*.json"
    doc: Result file for the processed site

baseCommand: [sh, -c]

arguments:
  - |
    echo "Starting processing of $(inputs.site_id)" >&2
    echo "{\"site_id\": \"$(inputs.site_id)\", \"status\": \"processed\"}" > $(runtime.outdir)/result_$(inputs.site_id).json

stdout: process_site.log
stderr: process_site.err

