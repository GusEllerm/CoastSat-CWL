cwlVersion: v1.2
class: CommandLineTool

$namespaces:
  cwltool: "http://commonwl.org/cwltool#"

label: Fetch NIWA tides for a single NZ site

doc: |
  Given a site_id, polygons.geojson, and a per-site directory containing
  transect_time_series.csv, fetches (or tops up) tides from the NIWA API
  and writes tides.csv for that site.
  
  This tool is intended to be scattered over NZD site IDs.
  It:
    - reads the polygon centroid for the site from polygons_geojson
    - reads dates from <site_id>/transect_time_series.csv
    - reuses any existing tides.csv from a persistent root, if provided
    - downloads only missing tides via NIWA's tides API
    - writes ./<site_id>/tides.csv and ./<site_id>/transect_time_series.csv
      in the step working directory

hints:
  cwltool:Secrets:
    secrets:
      - niwa_tide_api_key

requirements:
  InitialWorkDirRequirement:
    listing:
      - entryname: fetch_tides_nz_site.py
        entry: |
          #!/usr/bin/env python3
          import os
          import sys
          import argparse
          import warnings
          import time

          import pandas as pd
          import geopandas as gpd
          import requests
          from tqdm.auto import tqdm

          warnings.filterwarnings("ignore")


          def get_tide_for_dt(point, dt, api_key):
              """
              Fetch tide for a single datetime using NIWA tides API.

              point: shapely Point with .x (lon), .y (lat)
              dt: pandas.Timestamp (naive), rounded to 10 min
              api_key: NIWA API key string
              """
              while True:
                  try:
                      r = requests.get(
                          "https://api.niwa.co.nz/tides/data",
                          params={
                              "lat": point.y,
                              "long": point.x,
                              "numberOfDays": 2,
                              "startDate": str(dt.date()),
                              "datum": "MSL",
                              "interval": 10,  # minutes
                              "apikey": api_key,
                          },
                          timeout=(30, 30),
                      )
                  except Exception as e:
                      print(f"Error contacting NIWA API: {e}", file=sys.stderr)
                      time.sleep(5)
                      continue

                  if r.status_code == 200:
                      data = r.json()
                      df = pd.DataFrame(data["values"])
                      df.index = pd.to_datetime(df["time"])
                      try:
                          return df.loc[dt, "value"]
                      except KeyError:
                          # No exact match at dt; fall back to nearest time
                          nearest = df.index.get_indexer([dt], method="nearest")[0]
                          return df.iloc[nearest]["value"]
                  elif r.status_code == 429:
                      sleep_seconds = 30
                      print(
                          f"NIWA API rate limit hit (429). Sleeping {sleep_seconds}s...",
                          file=sys.stderr,
                      )
                      time.sleep(sleep_seconds)
                  else:
                      print(
                          f"NIWA API error {r.status_code}: {r.text}",
                          file=sys.stderr,
                      )
                      time.sleep(10)


          def main(argv=None) -> int:
              parser = argparse.ArgumentParser(
                  description="Fetch NIWA tides for a single NZ site."
              )
              parser.add_argument(
                  "--site-id", required=True, help="Site ID, e.g. nzd0001"
              )
              parser.add_argument(
                  "--polygons-geojson",
                  required=True,
                  help="Polygons GeoJSON file containing NZD polygons",
              )
              parser.add_argument(
                  "--site-dir",
                  required=True,
                  help="Per-site directory containing transect_time_series.csv "
                       "for the current run",
              )
              parser.add_argument(
                  "--existing-root",
                  required=False,
                  help="Optional root directory containing persistent per-site "
                       "tides.csv (e.g. small_data/)",
              )
              parser.add_argument(
                  "--niwa-tide-api-key",
                  required=True,
                  help="NIWA tide API key (string, marked as secret in CWL)",
              )

              args = parser.parse_args(argv)

              sitename = args.site_id
              site_dir_in = os.path.abspath(args.site_dir)
              ts_path_in = os.path.join(site_dir_in, "transect_time_series.csv")

              if not os.path.isfile(ts_path_in):
                  print(
                      f"No transect_time_series.csv found for {sitename} "
                      f"in {site_dir_in}",
                      file=sys.stderr,
                  )
                  return 1

              # Load polygons and get centroid for this site
              poly = gpd.read_file(args.polygons_geojson)
              poly = poly[poly.id == sitename]
              if poly.empty:
                  print(f"No polygon found for site {sitename}", file=sys.stderr)
                  return 1
              poly.set_index("id", inplace=True)
              point = poly.geometry[sitename].centroid

              # Load transect time series dates
              ts_df = pd.read_csv(ts_path_in)
              sat_times = pd.to_datetime(ts_df["dates"]).dt.round("10min")

              # Determine where existing tides may live
              existing_root = (
                  os.path.abspath(args.existing_root)
                  if args.existing_root
                  else None
              )
              tides_df = None

              if existing_root:
                  persistent_tides = os.path.join(
                      existing_root, sitename, "tides.csv"
                  )
                  if os.path.isfile(persistent_tides):
                      tides_df = pd.read_csv(persistent_tides)
                      tides_df.set_index("dates", inplace=True)
                      tides_df.index = pd.to_datetime(tides_df.index)
                      print(
                          f"Found existing tides for {sitename} in {persistent_tides}: "
                          f"{len(tides_df)} records",
                          file=sys.stderr,
                      )

              if tides_df is None:
                  # Optional: also look in the current per-run site dir
                  local_tides = os.path.join(site_dir_in, "tides.csv")
                  if os.path.isfile(local_tides):
                      tides_df = pd.read_csv(local_tides)
                      tides_df.set_index("dates", inplace=True)
                      tides_df.index = pd.to_datetime(tides_df.index)
                      print(
                          f"Found existing tides for {sitename} in {local_tides}: "
                          f"{len(tides_df)} records",
                          file=sys.stderr,
                      )
                  else:
                      tides_df = pd.DataFrame(columns=["tide"])
                      tides_df.index.name = "dates"

              # Dates we already have tides for
              if tides_df.empty:
                  existing_dates = pd.DatetimeIndex([])
              else:
                  existing_dates = tides_df.index

              missing = sat_times[~sat_times.isin(existing_dates)].unique()

              if len(missing) == 0:
                  print(
                      f"All {len(sat_times)} dates already have tides for {sitename}",
                      file=sys.stderr,
                  )
              else:
                  print(
                      f"Fetching tides for {len(missing)} missing dates at {sitename}",
                      file=sys.stderr,
                  )
                  results = []
                  for dt in tqdm(missing):
                      tide = get_tide_for_dt(point, dt, args.niwa_tide_api_key)
                      results.append({"dates": dt, "tide": tide})
                  new_tides = pd.DataFrame(results)
                  new_tides["dates"] = pd.to_datetime(new_tides["dates"])
                  new_tides.set_index("dates", inplace=True)

                  if tides_df.empty:
                      tides_df = new_tides
                  else:
                      tides_df = pd.concat([tides_df, new_tides])
                      tides_df = tides_df[~tides_df.index.duplicated(keep="first")]

              tides_df.sort_index(inplace=True)

              # Write outputs into ./<site_id>/ in this step's working dir
              site_dir_out = os.path.join(os.getcwd(), sitename)
              os.makedirs(site_dir_out, exist_ok=True)

              # Copy transect_time_series.csv through
              ts_path_out = os.path.join(site_dir_out, "transect_time_series.csv")
              ts_df.to_csv(ts_path_out, index=False)

              # Write tides.csv
              tides_path_out = os.path.join(site_dir_out, "tides.csv")
              tides_df.to_csv(tides_path_out)

              print(
                  f"Written tides for {sitename} to {tides_path_out} "
                  f"({len(tides_df)} rows)",
                  file=sys.stderr,
              )
              return 0


          if __name__ == "__main__":
              raise SystemExit(main())


baseCommand: [python3, fetch_tides_nz_site.py]

inputs:
  site_id:
    type: string
    doc: Site ID, e.g. nzd0001
    inputBinding:
      prefix: --site-id

  polygons_geojson:
    type: File
    inputBinding:
      prefix: --polygons-geojson

  site_dir_in:
    type: Directory
    doc: Per-site directory containing transect_time_series.csv for this run
    inputBinding:
      prefix: --site-dir
      valueFrom: $(self.path)

  existing_root:
    type: Directory?
    doc: Root directory containing any previously saved per-site tides.csv
    inputBinding:
      prefix: --existing-root
      valueFrom: $(self.path)

  niwa_tide_api_key:
    type: string
    inputBinding:
      prefix: --niwa-tide-api-key

stdout: fetch_tides.log

outputs:
  site_dir:
    type: Directory
    outputBinding:
      glob: $(inputs.site_id)

  tides_csv:
    type: File
    outputBinding:
      glob: $(inputs.site_id + "/tides.csv")
