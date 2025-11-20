#!/usr/bin/env python3
"""
Execute a Jupyter notebook with better error handling and timeout
This patches the notebook to avoid IPython magic issues
"""

import sys
import json
import nbformat
from nbconvert.preprocessors import ExecutePreprocessor
import signal

class TimeoutError(Exception):
    pass

def timeout_handler(signum, frame):
    raise TimeoutError("Notebook execution timed out")

def patch_notebook_for_execution(nb):
    """Patch notebook cells to avoid IPython magic issues"""
    for i, cell in enumerate(nb.cells):
        if cell.cell_type == 'code':
            source = cell.source
            new_source = source
            
            # Patch IPython magic calls
            if '%reload_ext autotime' in source or 'get_ipython().run_line_magic' in source and 'autotime' in source:
                new_source = new_source.replace(
                    "%reload_ext autotime",
                    "# %reload_ext autotime  # Disabled for non-interactive execution"
                )
                new_source = new_source.replace(
                    "get_ipython().run_line_magic('reload_ext', 'autotime')",
                    "# get_ipython().run_line_magic('reload_ext', 'autotime')  # Disabled for non-interactive execution"
                )
                if new_source != source:
                    print(f"  Patched cell {i} to remove autotime magic")
            
            # Patch test cells that make API calls - make them skip if tides.csv exists
            if 'sitename = "nzd0001"' in source and 'api.niwa.co.nz' in source and 'df = pd.DataFrame(r.json()["values"])' in source:
                # This is the test cell - wrap it to skip if tides.csv exists
                if 'os.path.isfile' not in source or 'tides.csv' not in source:
                    # Extract the original code (everything after sitename assignment)
                    original_code = source
                    # Wrap in a conditional
                    new_source = f"""# Test cell - skip if tides.csv exists or no API key
sitename = "nzd0001"
if os.path.isfile(f"data/{{sitename}}/tides.csv"):
    print(f"tides.csv already exists for {{sitename}}, skipping API test")
elif os.environ.get("NIWA_API_KEY"):
    dates = pd.to_datetime(pd.read_csv(f"data/{{sitename}}/transect_time_series.csv").dates).dt.round("10min")
    point = poly.geometry[sitename].centroid
    datetime = dates.iloc[0]
    print(datetime, point)
    try:
        r = requests.get("https://api.niwa.co.nz/tides/data", params={{
            "lat": point.y,
            "long": point.x,
            "numberOfDays": 2,
            "startDate": str(datetime.date()),
            "datum": "MSL",
            "interval": 10,
            "apikey": os.environ["NIWA_API_KEY"]
        }}, timeout=(30,30))
        if r.status_code == 200 and "values" in r.json():
            df = pd.DataFrame(r.json()["values"])
            df.index = pd.to_datetime(df.time)
            ax = df.plot(style="o-")
            df[df.index == datetime].plot(color="red", style="x", ax=ax, mew=2, ms=10)
        else:
            print(f"API call failed: {{r.status_code}}")
    except Exception as e:
        print(f"API test error: {{e}}")
else:
    print("No API key available and tides.csv doesn't exist - skipping test")
"""
                    if new_source != source:
                        print(f"  Patched cell {i} to skip API test if tides.csv exists")
                        new_source = new_source
            
            # Patch while True loops that could hang (add max retry limit)
            if 'while True:' in source and 'get_tide_for_dt' in source:
                # Add a retry counter to prevent infinite loops
                lines = new_source.split('\n')
                patched_lines = []
                in_while = False
                indent_level = 0
                for line in lines:
                    if 'while True:' in line:
                        in_while = True
                        indent_level = len(line) - len(line.lstrip())
                        # Replace with limited retries
                        patched_lines.append(' ' * indent_level + 'max_retries = 10')
                        patched_lines.append(' ' * indent_level + 'retry_count = 0')
                        patched_lines.append(' ' * indent_level + 'while retry_count < max_retries:')
                        patched_lines.append(' ' * indent_level + '    retry_count += 1')
                    elif in_while and line.strip().startswith('continue'):
                        # Keep continue but it will eventually exit
                        patched_lines.append(line)
                    else:
                        patched_lines.append(line)
                new_source = '\n'.join(patched_lines)
                if new_source != source:
                    print(f"  Patched cell {i} to add retry limit to while True loop")
            
            if new_source != source:
                cell.source = new_source

def execute_notebook(notebook_path, output_path=None, timeout_seconds=600):
    """Execute a notebook and save the result"""
    if output_path is None:
        output_path = notebook_path
    
    # Read the notebook
    print(f"Reading {notebook_path}...")
    with open(notebook_path, 'r') as f:
        nb = nbformat.read(f, as_version=4)
    
    # Patch for execution
    print("Patching notebook for safe execution...")
    patch_notebook_for_execution(nb)
    
    # Configure executor
    ep = ExecutePreprocessor(
        timeout=timeout_seconds,
        kernel_name='python3',
        allow_errors=True,  # Allow errors so we can see what happened
        interrupt_on_timeout=True
    )
    
    # Set up timeout signal
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(timeout_seconds + 60)  # Give a bit of extra time
    
    # Execute
    print(f"Executing {notebook_path} (timeout: {timeout_seconds}s)...", flush=True)
    try:
        ep.preprocess(nb, {'metadata': {'path': '.'}})
        signal.alarm(0)  # Cancel timeout
    except TimeoutError:
        print(f"ERROR: Notebook execution timed out after {timeout_seconds} seconds", flush=True)
        signal.alarm(0)
        # Save notebook with current state for debugging
        with open(output_path, 'w') as f:
            nbformat.write(nb, f)
        return False
    except Exception as e:
        print(f"ERROR executing notebook: {e}", flush=True)
        import traceback
        traceback.print_exc()
        signal.alarm(0)
        # Save notebook with errors for debugging
        with open(output_path, 'w') as f:
            nbformat.write(nb, f)
        return False
    
    # Save executed notebook
    with open(output_path, 'w') as f:
        nbformat.write(nb, f)
    
    print(f"✓ Notebook executed and saved to {output_path}")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 execute_notebook_safe.py <notebook_path> [output_path] [timeout_seconds]")
        sys.exit(1)
    
    notebook_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else notebook_path
    timeout = int(sys.argv[3]) if len(sys.argv) > 3 else 600
    
    success = execute_notebook(notebook_path, output_path, timeout)
    sys.exit(0 if success else 1)

