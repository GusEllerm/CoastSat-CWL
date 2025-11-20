cwlVersion: v1.2
class: ExpressionTool

requirements:
  - class: InlineJavascriptRequirement

inputs:
  nzd_results:
    type: Directory[]
  sar_results:
    type: Directory[]

expression: |
  ${
    var allResults = inputs.nzd_results.concat(inputs.sar_results);
    return { results: allResults };
  }

outputs:
  results:
    type: Directory[]
