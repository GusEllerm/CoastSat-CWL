#!/bin/bash

# CoastSat-CWL Workflow Runner
# Simplifies running the CoastSat-CWL workflow in Docker

set -e  # Exit on error

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DATA_DIR="${SCRIPT_DIR}/CoastSat-CWL/data"
DEFAULT_WORKFLOW="update_coastsat.cwl"
DEFAULT_DOCKER_IMAGE="coastsat-cwl"
DEFAULT_INPUT_FILE="input_small.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run the CoastSat-CWL workflow in a Docker container.

OPTIONS:
    -d, --data-dir DIR       Data directory to mount (default: ${DEFAULT_DATA_DIR})
    -c, --config-dir DIR     Directory containing input YAML file (required)
    -o, --output-dir DIR     Output directory (default: <config-dir>/out)
    -i, --input-file FILE    Input YAML file name (default: ${DEFAULT_INPUT_FILE})
    -w, --workflow FILE      Workflow CWL file (default: ${DEFAULT_WORKFLOW})
    -m, --docker-image IMG   Docker image name (default: ${DEFAULT_DOCKER_IMAGE})
    -h, --help               Show this help message

EXAMPLES:
    # Basic usage with defaults
    $0 -c CoastSat-CWL/tests/workflow/update_coastsat

    # Specify all parameters
    $0 -d /path/to/data -c /path/to/config -o /path/to/output -i input.yml

    # Use different workflow
    $0 -c CoastSat-CWL/tests/workflow/prepare_workflow_sites -w prepare_workflow_sites.cwl

EOF
}

# Parse command line arguments
DATA_DIR=""
CONFIG_DIR=""
OUTPUT_DIR=""
INPUT_FILE="${DEFAULT_INPUT_FILE}"
WORKFLOW="${DEFAULT_WORKFLOW}"
DOCKER_IMAGE="${DEFAULT_DOCKER_IMAGE}"

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        -c|--config-dir)
            CONFIG_DIR="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -i|--input-file)
            INPUT_FILE="$2"
            shift 2
            ;;
        -w|--workflow)
            WORKFLOW="$2"
            shift 2
            ;;
        -m|--docker-image)
            DOCKER_IMAGE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}" >&2
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$CONFIG_DIR" ]]; then
    echo -e "${RED}Error: --config-dir is required${NC}" >&2
    usage
    exit 1
fi

# Convert relative paths to absolute paths
CONFIG_DIR="$(cd "$CONFIG_DIR" && pwd)"
if [[ -n "$DATA_DIR" ]]; then
    DATA_DIR="$(cd "$DATA_DIR" && pwd)"
else
    DATA_DIR="${DEFAULT_DATA_DIR}"
    if [[ ! -d "$DATA_DIR" ]]; then
        echo -e "${YELLOW}Warning: Default data directory does not exist: ${DATA_DIR}${NC}" >&2
    fi
fi

# Set default output directory if not specified
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="${CONFIG_DIR}/out"
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# Validate input file exists
INPUT_FILE_PATH="${CONFIG_DIR}/${INPUT_FILE}"
if [[ ! -f "$INPUT_FILE_PATH" ]]; then
    echo -e "${RED}Error: Input file not found: ${INPUT_FILE_PATH}${NC}" >&2
    exit 1
fi

# Determine workflow path inside container
# If workflow is just a filename, assume it's in /workflow/workflow/
if [[ "$WORKFLOW" == *.cwl ]] && [[ "$WORKFLOW" != /* ]]; then
    WORKFLOW_PATH="/workflow/workflow/${WORKFLOW}"
else
    WORKFLOW_PATH="$WORKFLOW"
fi

# Print configuration
echo -e "${GREEN}CoastSat-CWL Workflow Runner${NC}"
echo "================================"
echo "Data directory:    ${DATA_DIR}"
echo "Config directory:  ${CONFIG_DIR}"
echo "Output directory:  ${OUTPUT_DIR}"
echo "Input file:        ${INPUT_FILE}"
echo "Workflow:          ${WORKFLOW}"
echo "Docker image:      ${DOCKER_IMAGE}"
echo ""

# Run Docker command
echo -e "${GREEN}Running workflow...${NC}"
docker run --rm \
  -v "${DATA_DIR}:/data" \
  -v "${CONFIG_DIR}:/cfg" \
  -v "${OUTPUT_DIR}:/out" \
  "${DOCKER_IMAGE}" \
  bash -lc "cwltool --no-container \
    --outdir /out \
    --provenance /out/prov_\$(date -u +%Y%m%dT%H%M%SZ) \
    ${WORKFLOW_PATH} \
    /cfg/${INPUT_FILE}"

echo ""
echo -e "${GREEN}Workflow completed!${NC}"
echo "Results are in: ${OUTPUT_DIR}"

