#!/usr/bin/env python3
"""
Validate CWL tool and workflow files.

This script validates CWL files using cwltool to ensure they are syntactically
correct and properly formatted.
"""

import sys
import subprocess
from pathlib import Path

def validate_cwl_file(cwl_path: Path) -> bool:
    """
    Validate a single CWL file using cwltool.
    
    Args:
        cwl_path: Path to the CWL file to validate
        
    Returns:
        True if valid, False otherwise
    """
    try:
        result = subprocess.run(
            ["cwltool", "--validate", str(cwl_path)],
            capture_output=True,
            text=True,
            check=True
        )
        print(f"✓ {cwl_path} is valid")
        return True
    except subprocess.CalledProcessError as e:
        print(f"✗ {cwl_path} validation failed:")
        print(e.stderr)
        return False

def main():
    """Validate all CWL files in tools/ and workflows/ directories."""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    tools_dir = project_root / "tools"
    workflows_dir = project_root / "workflows"
    
    all_valid = True
    
    # Validate tools
    if tools_dir.exists():
        print("Validating CWL tools...")
        for cwl_file in sorted(tools_dir.glob("*.cwl")):
            if not validate_cwl_file(cwl_file):
                all_valid = False
    else:
        print(f"⚠️  Tools directory not found: {tools_dir}")
    
    # Validate workflows
    if workflows_dir.exists():
        print("\nValidating CWL workflows...")
        for cwl_file in sorted(workflows_dir.glob("*.cwl")):
            if not validate_cwl_file(cwl_file):
                all_valid = False
    else:
        print(f"⚠️  Workflows directory not found: {workflows_dir}")
    
    if all_valid:
        print("\n✅ All CWL files are valid!")
        return 0
    else:
        print("\n❌ Some CWL files failed validation")
        return 1

if __name__ == "__main__":
    sys.exit(main())

