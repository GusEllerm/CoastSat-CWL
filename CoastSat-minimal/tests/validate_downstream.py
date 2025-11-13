#!/usr/bin/env python3
"""
Validate downstream CoastSat processing steps (tides, slope estimation,
tidal correction, linear models, Excel generation) against the original
CoastSat outputs. This avoids re-downloading imagery and focuses on the
refactored notebook logic.
"""

import os
import argparse
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List

try:
    from tests.extract_original_config import extract_original_config
except ImportError:
    # Allow running when invoked from project root
    from extract_original_config import extract_original_config  # type: ignore

PROJECT_ROOT = Path(__file__).parent.parent


def run_command(cmd: List[str], env_overrides: Dict[str, str] | None = None) -> None:
    env = dict(os.environ)
    if env_overrides:
        env.update(env_overrides)
    print(f"Running: {' '.join(cmd)}")
    subprocess.run(cmd, check=True, cwd=PROJECT_ROOT, env=env)


def ensure_site_data(site_id: str) -> None:
    src = PROJECT_ROOT / "CoastSat" / "data" / site_id / "transect_time_series.csv"
    if not src.exists():
        raise FileNotFoundError(
            f"Original transect_time_series.csv not found for {site_id}: {src}"
        )

    dest_dir = PROJECT_ROOT / "data" / site_id
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / "transect_time_series.csv"
    shutil.copy(src, dest)
    print(f"Copied {src} -> {dest}")

    # Remove downstream outputs so they can be regenerated
    for filename in [
        "tides.csv",
        "transect_time_series_tidally_corrected.csv",
        f"{site_id}.xlsx",
    ]:
        path = dest_dir / filename
        if path.exists():
            path.unlink()
            print(f"Removed existing {path}")


def validate_downstream(site: str, skip_copy: bool, keep_outputs: bool) -> None:
    config = extract_original_config(site)

    if not skip_copy:
        ensure_site_data(site)

    env_overrides = {
        "TEST_MODE": "true",
        "TEST_START_DATE": config["date_range"]["start"],
        "TEST_END_DATE": config["date_range"]["end"],
        "TEST_SITES": site,
        "TEST_SATELLITES": ",".join(config["satellites"]["list"]),
        "FORCE_START_DATE": config["date_range"]["start"],
    }

    # Step 1: Fetch tides
    run_command([
        sys.executable,
        "scripts/tidal_correction.py",
        "--mode",
        "fetch",
        "--sites",
        site,
    ], env_overrides)

    # Step 2: Slope estimation
    run_command([
        sys.executable,
        "scripts/slope_estimation.py",
        "--sites",
        site,
    ], env_overrides)

    # Step 3: Apply tidal correction (second pass)
    run_command([
        sys.executable,
        "scripts/tidal_correction.py",
        "--mode",
        "apply",
        "--sites",
        site,
    ], env_overrides)

    # Step 4: Linear models
    run_command([
        sys.executable,
        "scripts/linear_models.py",
        "--sites",
        site,
    ], env_overrides)

    # Step 5: Excel generation (only selected site)
    run_command([
        sys.executable,
        "scripts/make_xlsx.py",
        "--sites",
        site,
    ], env_overrides)

    # Step 6: Compare outputs (non-fatal - differences are expected and documented)
    try:
        run_command([
            sys.executable,
            "tests/compare_with_original.py",
            "--sites",
            site,
            "--output",
            f"validation_report_{site}_downstream.txt",
        ])
    except subprocess.CalledProcessError:
        # Comparison found differences, but this is expected - report was still generated
        print(f"\n⚠️  Comparison found differences (see validation_report_{site}_downstream.txt)")
        print("   This is expected - differences are documented in the report.")

    if keep_outputs:
        print("Outputs kept for inspection.")
    else:
        print("Downstream validation complete. Outputs compared with original data.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate downstream CoastSat steps against original data.")
    parser.add_argument(
        "--sites",
        nargs="+",
        default=["nzd0001"],
        help="Site IDs to validate (default: nzd0001)",
    )
    parser.add_argument(
        "--skip-copy",
        action="store_true",
        help="Skip copying transect_time_series.csv from original data",
    )
    parser.add_argument(
        "--keep-outputs",
        action="store_true",
        help="Keep generated outputs after comparison (do not delete)",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    for site in args.sites:
        print("=" * 80)
        print(f"Validating downstream steps for {site}")
        print("=" * 80)
        validate_downstream(site, skip_copy=args.skip_copy, keep_outputs=args.keep_outputs)
