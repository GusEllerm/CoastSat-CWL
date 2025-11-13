#!/usr/bin/env python3
"""
Run the minimal CoastSat workflow and validate outputs.
This script runs the workflow and then validates the outputs.
"""

import subprocess
import sys
from pathlib import Path

# Get project root directory
project_root = Path(__file__).parent.parent

def run_workflow():
    """Run the minimal workflow."""
    print("=" * 60)
    print("Running CoastSat Minimal Workflow")
    print("=" * 60)
    print()
    
    workflow_script = project_root / 'workflow' / 'workflow.sh'
    
    if not workflow_script.exists():
        print(f"Error: Workflow script not found: {workflow_script}")
        sys.exit(1)
    
    # Run workflow
    try:
        result = subprocess.run(
            ['bash', str(workflow_script)],
            cwd=str(project_root),
            check=True,
            capture_output=False
        )
        print()
        print("Workflow completed successfully!")
        return True
    except subprocess.CalledProcessError as e:
        print()
        print(f"Error: Workflow failed with exit code {e.returncode}")
        sys.exit(1)

def main():
    """Main function."""
    # Run workflow
    success = run_workflow()
    
    if success:
        # Validate outputs
        print()
        print("=" * 60)
        print("Validating outputs...")
        print("=" * 60)
        print()
        
        validate_script = project_root / 'tests' / 'validate_outputs.py'
        subprocess.run([sys.executable, str(validate_script)], cwd=str(project_root))

if __name__ == '__main__':
    main()

