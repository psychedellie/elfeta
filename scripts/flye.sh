#!/usr/bin/env bash
set -euo pipefail

# Usage: flye.sh <np_raw_file> <flye_dir> <threads> [optional_flye_args]
if [ $# -lt 3 ]; then
    echo "Usage: $0 <np_raw_file> <flye_dir> <threads> [args]" >&2
    exit 2
fi

np_raw_file="$1"
outdir="$2"
threads="$3"
args="${4:-}"

# Ensure output directory exists
mkdir -p "$outdir"

# Run Flye assembler
flye ${args} \
    --nano-hq "$np_raw_file" \
    --out-dir "$outdir" \
    --threads "$threads"

flye --version > versions.txt
