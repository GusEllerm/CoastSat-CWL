#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: ExpressionTool

doc: |
  ExpressionTool to extract nzd and sar prefix lists from grouped IDs.
  
  This tool extracts the "nzd" and "sar" prefix lists from the grouped_ids_array,
  making them ready for direct handoff to subsequent workflow steps.
  
  To add more prefix lists in the future, simply add additional outputs following
  the same pattern.

label: Get NZD and SAR Lists

requirements:
  - class: InlineJavascriptRequirement

inputs:
  grouped_ids_array:
    type:
      type: array
      items:
        type: array
        items: string
    doc: Array of arrays of strings from read_grouped_ids_array tool output

expression: |
  ${ 
    function findPrefixList(prefix) {
      for (var i = 0; i < inputs.grouped_ids_array.length; i++) {
        if (inputs.grouped_ids_array[i].length > 0) {
          var firstId = inputs.grouped_ids_array[i][0].toLowerCase();
          var prefixMatch = firstId.match(/^([^0-9]+)/);
          if (prefixMatch && prefixMatch[1] === prefix) {
            return inputs.grouped_ids_array[i];
          }
        }
      }
      return [];
    }
    return {
      nzd_list: findPrefixList("nzd"),
      sar_list: findPrefixList("sar")
    };
  }

outputs:
  nzd_list:
    type: string[]
    doc: |
      List of NZD site IDs (string[]).
      Can be directly passed to subsequent workflow steps.
  
  sar_list:
    type: string[]
    doc: |
      List of SAR site IDs (string[]).
      Can be directly passed to subsequent workflow steps.

