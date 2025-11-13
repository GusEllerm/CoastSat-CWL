#!/usr/bin/env python3
"""
Test script to run the full CoastSat workflow.
This script runs all steps of the workflow in test mode.
"""

import os
import sys
import subprocess
from pathlib import Path
from dotenv import load_dotenv

# Get project root directory
project_root = Path(__file__).parent.parent
os.chdir(project_root)

# Load environment variables
load_dotenv()

def run_command(cmd, description):
    """Run a command and handle errors."""
    print(f"\n{'=' * 60}")
    print(f"Step: {description}")
    print(f"Command: {cmd}")
    print(f"{'=' * 60}\n")
    
    result = subprocess.run(
        cmd,
        shell=True,
        capture_output=False,
        text=True
    )
    
    if result.returncode != 0:
        print(f"\n❌ Error in {description}")
        print(f"Exit code: {result.returncode}")
        sys.exit(1)
    
    print(f"\n✅ {description} completed successfully")
    return result

def main():
    """Run the full workflow."""
    
    # Check test mode
    test_mode = os.getenv('TEST_MODE', 'false').lower() == 'true'
    if not test_mode:
        print("⚠️  WARNING: TEST_MODE is not enabled!")
        print("This will download a large amount of data (400 MB - 40 GB).")
        response = input("Continue anyway? (yes/no): ")
        if response.lower() != 'yes':
            print("Aborted. Enable TEST_MODE in .env file to limit data download.")
            sys.exit(1)
    
    print("=" * 60)
    print("CoastSat Full Workflow Test")
    print("=" * 60)
    print(f"Project root: {project_root}")
    print(f"Test mode: {test_mode}")
    if test_mode:
        print(f"Test start date: {os.getenv('TEST_START_DATE', 'N/A')}")
        print(f"Test end date: {os.getenv('TEST_END_DATE', 'N/A')}")
        print(f"Test sites: {os.getenv('TEST_SITES', 'N/A')}")
        print(f"Test satellites: {os.getenv('TEST_SATELLITES', 'N/A')}")
    print("=" * 60)
    
    # Step 1: Batch process NZ sites
    run_command(
        "python3 scripts/batch_process_NZ.py",
        "Batch processing NZ sites"
    )
    
    # Step 2: Batch process SAR sites
    run_command(
        "python3 scripts/batch_process_sar.py",
        "Batch processing SAR sites"
    )
    
    # Step 3: Run tidal correction (first pass)
    run_command(
        "python3 scripts/tidal_correction.py --mode fetch",
        "Tidal correction (first pass - fetch tides)"
    )
    
    # Step 4: Run slope estimation
    run_command(
        "python3 scripts/slope_estimation.py",
        "Slope estimation"
    )
    
    # Step 5: Run tidal correction (second pass)
    run_command(
        "python3 scripts/tidal_correction.py --mode apply",
        "Tidal correction (second pass - apply correction)"
    )
    
    # Step 6: Run linear models
    run_command(
        "python3 scripts/linear_models.py",
        "Linear models"
    )
    
    # Step 7: Make Excel files
    run_command(
        "python3 scripts/make_xlsx.py",
        "Creating Excel files"
    )
    
    # Step 8: Validate outputs
    print(f"\n{'=' * 60}")
    print("Validating outputs")
    print(f"{'=' * 60}\n")
    
    result = subprocess.run(
        "python3 tests/validate_outputs.py",
        shell=True,
        capture_output=False,
        text=True
    )
    
    if result.returncode == 0:
        print("\n✅ All outputs validated successfully")
    else:
        print("\n⚠️  Validation found some issues (see above)")
    
    print("\n" + "=" * 60)
    print("Workflow completed!")
    print("=" * 60)
    
    # Show data usage if in test mode
    if test_mode:
        print("\nData usage summary:")
        for site_dir in Path("data").glob("*/"):
            if site_dir.is_dir():
                size = sum(f.stat().st_size for f in site_dir.rglob("*") if f.is_file())
                print(f"  {site_dir.name}: {size / 1024 / 1024:.2f} MB")

if __name__ == "__main__":
    main()

