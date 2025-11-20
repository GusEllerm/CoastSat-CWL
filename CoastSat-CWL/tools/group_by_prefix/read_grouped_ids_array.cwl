#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

doc: |
  Tool to read the grouped_ids JSON file and pass it through.
  This is a workaround since ExpressionTools can't handle large files with loadContents.

label: Read Grouped IDs Array

requirements:
  - class: InitialWorkDirRequirement
    listing:
      - entryname: read_grouped_ids_array.py
        entry: |
          #!/usr/bin/env python3
          """Read JSON file and output as JSON array (passthrough for CWL)."""
          import argparse
          import json
          import os
          import sys

          def main() -> int:
              parser = argparse.ArgumentParser(
                  description="Read JSON file and output as JSON array"
              )
              parser.add_argument(
                  "--input",
                  required=True,
                  help="Path to input JSON file",
              )
              parser.add_argument(
                  "--output-dir",
                  required=True,
                  help="Output directory for JSON file",
              )

              args = parser.parse_args()

              try:
                  # Read input JSON file
                  with open(args.input, "r") as f:
                      data = json.load(f)

                  # Ensure output directory exists
                  os.makedirs(args.output_dir, exist_ok=True)

                  # Construct output file path
                  output_path = os.path.join(args.output_dir, "grouped_ids_array.json")

                  # Write output JSON file
                  with open(output_path, "w") as f:
                      json.dump(data, f)

                  print(f"Output written to: {output_path}")
                  return 0

              except FileNotFoundError:
                  print(f"Error: file not found: {args.input}", file=sys.stderr)
                  return 1
              except json.JSONDecodeError as e:
                  print(f"Error: invalid JSON in input file: {e}", file=sys.stderr)
                  return 1
              except Exception as e:
                  print(f"Error: {e}", file=sys.stderr)
                  return 1

          if __name__ == "__main__":
              sys.exit(main())

inputs:
  grouped_ids_json:
    type: File
    doc: The JSON file output from group_by_prefix tool

baseCommand: [python3, read_grouped_ids_array.py]

arguments:
  - --input
  - $(inputs.grouped_ids_json)
  - --output-dir
  - $(runtime.outdir)

outputs:
  grouped_ids_array_file:
    type: File
    outputBinding:
      glob: "grouped_ids_array.json"
    doc: JSON file containing the array (for use with ExpressionTool)
