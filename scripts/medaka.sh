#!/usr/bin/env bash
set -euo pipefail

# Usage: medaka.sh <np_raw_file> <assembly> <outdir> <threads> <model> [optional_medaka_args]
if [ $# -lt 5 ]; then
    echo "Usage: $0 <np_raw_file> <assembly> <outdir> <threads> <model> [args]" >&2
    exit 2
fi

np_raw_file="$1"
assembly="$2"
outdir="$3"
threads="$4"
args="${5:-}"

# Clean up output directory if it exists (Medaka can fail if dir exists)
if [ -d "$outdir" ]; then
    echo "[Medaka] Deleting existing output folder: $outdir"
    rm -rf "$outdir"
fi

# Run Medaka
medaka_consensus ${args} \
    -i "$np_raw_file" \
    -d "$assembly" \
    -o "$outdir" \
    -t "$threads"

medaka --version > versions.txt