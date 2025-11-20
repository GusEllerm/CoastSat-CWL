#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: ExpressionTool

doc: |
  ExpressionTool to convert the JSON file to a string[][] array.
  This reads from a file that was prepared by read_grouped_ids_array.cwl.

label: Convert Grouped IDs to Array

requirements:
  - class: InlineJavascriptRequirement

inputs:
  grouped_ids_array_file:
    type: File
    loadContents: true
    doc: JSON file from read_grouped_ids_array tool

expression: |
  ${ 
    var data = JSON.parse(inputs.grouped_ids_array_file.contents);
    return {grouped_ids_array: data};
  }

outputs:
  grouped_ids_array:
    type:
      type: array
      items:
        type: array
        items: string
    doc: Array of arrays of strings, directly usable in subsequent steps.

