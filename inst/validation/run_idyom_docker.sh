#!/usr/bin/env bash
# Build the ppidyom IDyOM validation Docker image (once) and run the
# reference-data generator script inside it.
#
# Usage (from the repo root or from inst/validation/):
#   bash inst/validation/run_idyom_docker.sh                                  # main fixture
#   bash inst/validation/run_idyom_docker.sh generate_idyom_sd_reference.py   # shortest-deterministic fixture
#
# Output: tests/testthat/fixtures/idyom_reference_ic.csv (or idyom_reference_sd.csv)

set -euo pipefail

IMAGE="ppidyom-idyom-validation"
GENERATOR="${1:-generate_idyom_reference.py}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Repo root : $REPO_ROOT"
echo "Image     : $IMAGE"
echo ""

# Build image only if it does not already exist.
if [[ "$(docker images -q "$IMAGE" 2>/dev/null)" == "" ]]; then
    echo "Building Docker image $IMAGE (this takes a few minutes the first time)..."
    docker build -t "$IMAGE" "$SCRIPT_DIR"
else
    echo "Image $IMAGE already exists — skipping build."
fi

echo ""
echo "Running $GENERATOR inside container..."
docker run --rm \
    -v "$REPO_ROOT:/work" \
    -w "/work/inst/validation" \
    "$IMAGE" \
    python3 "$GENERATOR"

echo ""
echo "Done. Fixture written to tests/testthat/fixtures/ (see the generator's output above)."
