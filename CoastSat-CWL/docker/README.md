# Docker Environment

This directory contains the Docker configuration for the CoastSat-CWL workflow.

## Base Image

The base Docker image (`Dockerfile`) contains all dependencies required for the CoastSat workflow:
- Python 3.11+
- All Python packages from `requirements.txt`
- GDAL with Python bindings
- System libraries required for geospatial processing

## Building the Image

### Quick Build
```bash
docker build -t coastsat-cwl:latest .
```

### Using Build Script
```bash
./build.sh [tag]
```
The build script will:
- Check for `requirements.txt` and copy from `CoastSat-minimal/` if needed
- Build the image with appropriate tag
- Display test commands

## Testing the Image

### Quick Test
```bash
docker run --rm coastsat-cwl:latest python3 -c "from coastsat import SDS_download; print('CoastSat imported successfully')"
```

### Comprehensive Test Suite
```bash
./test.sh [tag]
```
The test script will verify:
- Python version
- GDAL installation
- GeoPandas import
- CoastSat import
- Other key dependencies

## PyQt5 and Memory Issues

**Important**: PyQt5 is required by `coastsat_package` but is only needed for Jupyter notebooks, not for the command-line CWL workflow. The Dockerfile attempts to install `coastsat_package` without dependencies first, falling back to a full install if needed.

If you encounter memory issues during PyQt5 compilation:

1. **Increase Docker Desktop Memory** (recommended):
   - Docker Desktop → Settings → Resources → Advanced
   - Increase Memory to **8 GB**
   - Apply & Restart

2. **Use Alternative Dockerfile** (experimental):
   - Try `Dockerfile.nojupyter` which attempts to skip PyQt5/Jupyter dependencies
   ```bash
   docker build -f Dockerfile.nojupyter -t coastsat-cwl:nojupyter .
   ```
   - Note: This may not work if PyQt5 is a hard runtime dependency

See `MEMORY_ISSUES.md` for detailed troubleshooting.

## Usage in CWL

The Docker image is referenced in CWL tool definitions via:

### Published Image
```yaml
requirements:
  DockerRequirement:
    dockerPull: coastsat-cwl:latest
```

### Local Development
```yaml
requirements:
  DockerRequirement:
    dockerImageId: coastsat-cwl:latest
```

Note: For local development, the image must be built locally first.

## Dependencies

See `requirements.txt` for Python package dependencies. This file should be kept in sync with `../CoastSat-minimal/requirements.txt`.
