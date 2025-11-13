#!/usr/bin/env python3
"""
Run CWL workflow and collect outputs for comparison.

This script executes a CWL workflow and prepares outputs for comparison
with the minimal implementation.
"""

import sys
import subprocess
import json
from pathlib import Path
from typing import Optional

def run_cwl_workflow(
    workflow_file: Path,
    input_file: Path,
    output_dir: Optional[Path] = None,
    generate_provenance: bool = False
) -> bool:
    """
    Run a CWL workflow.
    
    Args:
        workflow_file: Path to CWL workflow file
        input_file: Path to workflow input JSON/YAML file
        output_dir: Optional output directory for results
        generate_provenance: If True, use cwlprov instead of cwltool
        
    Returns:
        True if successful, False otherwise
    """
    try:
        cmd = ["cwlprov", "run"] if generate_provenance else ["cwltool"]
        
        if output_dir:
            cmd.extend(["--outdir", str(output_dir)])
        
        cmd.extend([str(workflow_file), str(input_file)])
        
        print(f"Running: {' '.join(cmd)}")
        result = subprocess.run(
            cmd,
            capture_output=False,
            text=True,
            check=True
        )
        
        print(f"\n✅ Workflow completed successfully")
        
        if generate_provenance:
            print(f"   Provenance records generated")
        
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Workflow failed with exit code {e.returncode}")
        return False
    except FileNotFoundError:
        tool = "cwlprov" if generate_provenance else "cwltool"
        print(f"❌ Error: {tool} not found. Install with: pip install {tool}")
        return False

def main():
    """Main function."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Run CWL workflow")
    parser.add_argument("workflow", type=Path, help="Path to CWL workflow file")
    parser.add_argument("inputs", type=Path, help="Path to workflow input file")
    parser.add_argument("--outdir", type=Path, help="Output directory for results")
    parser.add_argument("--provenance", action="store_true", 
                       help="Generate provenance records using cwlprov")
    
    args = parser.parse_args()
    
    # Set default output directory
    if not args.outdir:
        args.outdir = Path(__file__).parent / "outputs" / "cwl"
    
    args.outdir.mkdir(parents=True, exist_ok=True)
    
    success = run_cwl_workflow(
        args.workflow,
        args.inputs,
        args.outdir,
        args.provenance
    )
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())

