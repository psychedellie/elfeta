#!/usr/bin/env bash
set -euo pipefail

consensus=$1
label=$2
output=$3

# Ensure parent dir exists
mkdir -p "$(dirname "$output")"

# Run MLST, but don’t kill the pipeline if no ST is found
micromamba run -n mlst mlst "$consensus" --label "$label" --quiet > "$output" || true
