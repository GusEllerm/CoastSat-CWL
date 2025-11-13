#!/usr/bin/env cwl-runner
# Simple test CWL tool to verify environment setup
cwlVersion: v1.2

class: CommandLineTool

baseCommand: python3

arguments:
  - -c
  - |
    from coastsat import SDS_download, SDS_tools
    print("CoastSat modules imported successfully")
    print("Test passed!")

inputs: []

requirements:
  DockerRequirement:
    dockerImageId: coastsat-cwl:latest

outputs:
  test_output:
    type: stdout

