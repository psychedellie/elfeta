#!/usr/bin/env bash
set -euo pipefail

# Usage: mlst.sh <consensus> <label> <output>
if [ $# -lt 3 ]; then
    echo "Usage: $0 <consensus> <label> <output>" >&2
    exit 2
fi

consensus="$1"
label="$2"
output="$3"

# Ensure parent dir exists
mkdir -p "$(dirname "$output")"

# Run MLST, but don’t kill the pipeline if no ST is found
mlst \
    "$consensus" \
    --label "$label" \
    > "$output" || true

mlst --version > versions.txt