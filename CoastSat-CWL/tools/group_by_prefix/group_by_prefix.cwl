#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

doc: |
  Tool that groups polygon IDs by prefix from a GeoJSON file.
  
  Takes a GeoJSON FeatureCollection file and extracts IDs from features -> properties -> id.
  Groups IDs by their prefix (e.g., "aus", "nzd", "sar") and outputs a JSON array
  of arrays where each inner array contains IDs with the same prefix.

label: Group IDs by Prefix

requirements:
  - class: InitialWorkDirRequirement
    listing:
      - entryname: group_by_prefix.py
        entry: |
          #!/usr/bin/env python3
          import argparse
          import json
          import os
          import re
          import sys
          from collections import defaultdict
          
          
          def extract_prefix(site_id: str) -> str:
              """
              Extract the prefix (leading non-digit characters) from a site ID.
              Examples:
                "aus0001" -> "aus"
                "nzd10"   -> "nzd"
                "sar"     -> "sar"
                "123abc"  -> ""
              """
              match = re.match(r"\D*", site_id)
              return match.group(0) if match else site_id
          
          
          def main() -> int:
              parser = argparse.ArgumentParser(
                  description="Group polygon IDs by prefix from GeoJSON file"
              )
              parser.add_argument(
                  "--input",
                  required=True,
                  help="Path to input GeoJSON file",
              )
              parser.add_argument(
                  "--output-dir",
                  required=True,
                  help="Output directory for grouped IDs JSON file",
              )
          
              args = parser.parse_args()
          
              # Load the input GeoJSON file
              try:
                  with open(args.input, "r") as f:
                      data = json.load(f)
              except FileNotFoundError:
                  print(f"Error: file not found: {args.input}", file=sys.stderr)
                  return 1
              except json.JSONDecodeError as e:
                  print(f"Error: invalid JSON in input file: {e}", file=sys.stderr)
                  return 1
          
              # Verify it's a FeatureCollection
              if data.get("type") != "FeatureCollection":
                  print(
                      f"Error: input must be a GeoJSON FeatureCollection, "
                      f"got type: {data.get('type')}",
                      file=sys.stderr,
                  )
                  return 1
          
              # Group IDs by prefix
              grouped = defaultdict(list)
              for feature in data.get("features", []):
                  site_id = feature.get("properties", {}).get("id")
                  if not site_id:
                      continue
                  prefix = extract_prefix(site_id)
                  grouped[prefix].append(site_id)
          
              sorted_prefixes = sorted(grouped.keys())
              result = [grouped[p] for p in sorted_prefixes]
          
              os.makedirs(args.output_dir, exist_ok=True)
              output_path = os.path.join(args.output_dir, "grouped_ids.json")
          
              with open(output_path, "w") as f:
                  json.dump(result, f, indent=2)
          
              total_ids = sum(len(g) for g in result)
              print(f"Grouped {total_ids} IDs into {len(result)} prefix groups")
              for prefix in sorted_prefixes:
                  print(f"  {prefix}: {len(grouped[prefix])} sites")
              print(f"Output written to: {output_path}")
          
              return 0
        
          if __name__ == "__main__":
              sys.exit(main())

inputs:
  polygons_geojson:
    type: File
    inputBinding:
      prefix: --input
    doc: |
      GeoJSON FeatureCollection file containing polygon features.
      Each feature should have a properties.id field with a site identifier.

outputs:
  grouped_ids:
    type: File
    outputBinding:
      glob: "grouped_ids.json"
    doc: |
      JSON file containing an array of arrays of strings.
      Each inner array contains site IDs grouped by their prefix.
      Format: [["aus0001", "aus0002", ...], ["nzd0001", "nzd0002", ...], ...]

baseCommand: [python3, group_by_prefix.py]

arguments:
  - --output-dir
  - $(runtime.outdir)

stdout: group_by_prefix.log
stderr: group_by_prefix.err
