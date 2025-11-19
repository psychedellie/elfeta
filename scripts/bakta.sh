#!/usr/bin/env bash
set -euo pipefail

# Usage: bakta.sh <consensus> <output_dir> <sample_name> <threads> <db_path> [args]
if [ $# -lt 5 ]; then
    echo "Usage: $0 <consensus> <output_dir> <sample_name> <threads> <db_path> [args]" >&2
    exit 2
fi

consensus="$1"
output="$2"
sample_name="$3"
threads="$4"
database="$5"
args="${6:-}"

mkdir -p "$output"

# Run Bakta
# Note: Input file ($consensus) typically goes at the end for Bakta
bakta --output "$output" \
      --prefix "$sample_name" \
      --threads "$threads" \
      --db "$database" \
      $args \
      "$consensus"