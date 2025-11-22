cwlVersion: v1.2
class: CommandLineTool

label: Create trimmed per-site directory without imagery

requirements:
  InitialWorkDirRequirement:
    listing:
      - entryname: trim_site_dir.py
        entry: |
          #!/usr/bin/env python3
          import argparse
          import os
          import shutil
          import sys

          def main(argv=None):
              p = argparse.ArgumentParser(
                  description="Copy core outputs for a site into a clean directory"
              )
              p.add_argument("--site-id", required=True)
              p.add_argument("--src-dir", required=True)
              args = p.parse_args(argv)

              site_id = args.site_id
              src = os.path.abspath(args.src_dir)

              # Destination: a new directory named <site_id> in the CWL working dir
              dst = os.path.join(os.getcwd(), site_id)
              os.makedirs(dst, exist_ok=True)

              # Files we definitely want to keep if present
              keep_names = {
                  "transect_time_series.csv",
                  "transect_time_series_tidally_corrected.csv",
                  "transect_time_series_despiked.csv",
                  "transect_time_series_smoothed.csv",
                  "tides.csv",
                  f"{site_id}.xlsx",
              }

              # File extensions we treat as "imagery" to drop
              image_exts = {".tif", ".tiff", ".png", ".jpg", ".jpeg", ".gif"}

              for name in os.listdir(src):
                  src_path = os.path.join(src, name)
                  if os.path.isdir(src_path):
                      # Skip all subdirectories (they usually hold imagery)
                      continue

                  ext = os.path.splitext(name)[1].lower()

                  # Explicit keep by name
                  if name in keep_names:
                      shutil.copy2(src_path, os.path.join(dst, name))
                      continue

                  # Skip obvious imagery
                  if ext in image_exts:
                      continue

                  # For everything else (non-imagery), keep by default
                  shutil.copy2(src_path, os.path.join(dst, name))

              print(f"[{site_id}] Created trimmed directory at {dst}", file=sys.stderr)
              return 0

          if __name__ == "__main__":
              raise SystemExit(main())

baseCommand: [python3, trim_site_dir.py]

inputs:
  site_id:
    type: string
    inputBinding:
      prefix: --site-id

  src_dir:
    type: Directory
    inputBinding:
      prefix: --src-dir

outputs:
  site_dir:
    type: Directory
    outputBinding:
      glob: $(inputs.site_id)
