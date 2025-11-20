cwlVersion: v1.2
class: CommandLineTool

doc: |
  Example CommandLineTool that:
  - receives GEE private key JSON and NIWA_TIDE_API_KEY as inputs
  - writes the GEE key to a temporary file
  - sets GOOGLE_APPLICATION_CREDENTIALS and NIWA_TIDE_API_KEY
  - prints a simple confirmation (no secrets are printed)

baseCommand: [python3, use_gee_secrets.py]

requirements:
  InitialWorkDirRequirement:
    listing:
      - entryname: use_gee_secrets.py
        entry: |
          #!/usr/bin/env python3
          import json
          import os
          import sys
          import tempfile

          def main():
              # Inputs come in via positional arguments
              gee_key_json = sys.argv[1]
              niwa_tide_api_key = sys.argv[2]

              # Write the GEE JSON to a temporary file
              fd, key_path = tempfile.mkstemp(prefix="gee-key-", suffix=".json")
              os.close(fd)
              with open(key_path, "w") as f:
                  f.write(gee_key_json)

              # Export the environment variables for any downstream processes
              os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = key_path
              os.environ["NIWA_TIDE_API_KEY"] = niwa_tide_api_key

              # Example of how you *might* load and use the key
              # (replace this with ee.ServiceAccountCredentials, etc.)
              with open(key_path, "r") as f:
                  key_data = json.load(f)
              client_email = key_data.get("client_email", "<missing>")

              # IMPORTANT: don't print the secrets themselves.
              # Just confirm that things are wired up.
              print("GEE key loaded for client_email:", client_email)
              print("GOOGLE_APPLICATION_CREDENTIALS set to:", key_path)
              print("NIWA_TIDE_API_KEY is set (value not shown).")

          if __name__ == "__main__":
              main()

inputs:
  gee_key_json:
    type: string
    inputBinding:
      position: 1
  niwa_tide_api_key:
    type: string
    inputBinding:
      position: 2

stdout: credentials_summary.txt

outputs:
  credentials_summary:
    type: File
    outputBinding:
      glob: credentials_summary.txt
