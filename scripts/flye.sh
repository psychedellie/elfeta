#!/usr/bin/env bash
set -euo pipefail

# Usage: flye.sh <np_raw_file> <flye_dir> <threads> [optional_flye_args]
if [ $# -lt 3 ]; then
    echo "Usage: $0 <np_raw_file> <flye_dir> <threads> [args]" >&2
    exit 2
fi

np_raw_file="$1"
flye_dir="$2"
threads="$3"
args="${4:-}"

# Ensure output directory exists
mkdir -p "$flye_dir"

# Run Flye assembler
flye --nano-hq "$np_raw_file" \
    --out-dir "$flye_dir" \
    --threads "$threads" \
    $args
