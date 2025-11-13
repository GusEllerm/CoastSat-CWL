# Docker Environment

This directory contains the Docker configuration for the CoastSat-CWL workflow.

## Base Image

The base Docker image (`Dockerfile`) contains all dependencies required for the CoastSat workflow:
- Python 3.11+
- All Python packages from `requirements.txt`
- GDAL with Python bindings
- System libraries required for geospatial processing

## Building the Image

```bash
docker build -t coastsat-cwl:latest .
```

## Usage

The Docker image is referenced in CWL tool definitions via:
```yaml
requirements:
  DockerRequirement:
    dockerPull: coastsat-cwl:latest
```

Or for local development:
```yaml
requirements:
  DockerRequirement:
    dockerImageId: coastsat-cwl:latest
```

## Development

To test the image:
```bash
docker run -it coastsat-cwl:latest python3 -c "from coastsat import SDS_download; print('CoastSat imported successfully')"
```

## Dependencies

See `requirements.txt` for Python package dependencies. This file should be kept in sync with `../CoastSat-minimal/requirements.txt`.

