#!/usr/bin/env bash
set -euo pipefail

# Usage: medaka.sh <np_raw_file> <assembly> <output_dir> <threads> <model> [optional_medaka_args]
if [ $# -lt 5 ]; then
    echo "Usage: $0 <np_raw_file> <assembly> <output_dir> <threads> <model> [args]" >&2
    exit 2
fi

np_raw_file="$1"
assembly="$2"
output_dir="$3"
threads="$4"
args="${5:-}"

# Clean up output directory if it exists (Medaka can fail if dir exists)
if [ -d "$output_dir" ]; then
    echo "[Medaka] Deleting existing output folder: $output_dir"
    rm -rf "$output_dir"
fi

# Run Medaka
medaka_consensus \
    -i "$np_raw_file" \
    -d "$assembly" \
    -o "$output_dir" \
    -t "$threads" \
    $args
