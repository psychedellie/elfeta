#!/usr/bin/env bash
set -euo pipefail

# Usage: plasmidfinder.sh <assembly> <out_dir> <db> [optional_args]
if [ $# -lt 3 ]; then
    echo "Usage: $0 <assembly> <out_dir> <db> [optional_args]" >&2
    exit 2
fi

# Assign required arguments to variables
consensus="$1"
output="$2"
database="$3"
args="${4:-}"

# Create output directory
mkdir -p "$output"

# Run PlasmidFinder with arguments
plasmidfinder.py \
    -i "$consensus" \
    -p "$database" \
    -o "$output" \
    $args