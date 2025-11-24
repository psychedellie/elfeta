#!/usr/bin/env bash
set -euo pipefail

# Usage: bakta.sh <consensus> <outdir> <sample_name> <threads> <db_path> [args]
if [ $# -lt 5 ]; then
    echo "Usage: $0 <consensus> <outdir> <sample_name> <threads> <db_path> [args]" >&2
    exit 2
fi

consensus="$1"
outdir="$2"
sample_name="$3"
threads="$4"
database="$5"
args="${6:-}"

mkdir -p "$outdir"

# Run Bakta
# Note: Input file ($consensus) typically goes at the end for Bakta
bakta ${args} \
      --output "$outdir" \
      --prefix "$sample_name" \
      --threads "$threads" \
      --db "$database" \
      "$consensus"
