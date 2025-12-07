#!/usr/bin/env bash
set -euo pipefail

# Usage: polypolish_filter.sh <sam1> <sam2> <sample_id>
if [ $# -lt 3 ]; then
    echo "Usage: $0 <sam1> <sam2> <sample_id>" >&2
    exit 2
fi

# Assign arguments to variables
sam1="$1"
sam2="$2"
sample_id="$3"
args="${4:-}"

# Define output file path
outdir="samples/${sample_id}/polypolish"

# Create output directory
mkdir -p "$outdir"

# Run Polypolish filter
polypolish filter ${args} \
    --in1 "$sam1" \
    --in2 "$sam2" \
    --out1 "${outdir}/${sample_id}.filtered_1.sam" \
    --out2 "${outdir}/${sample_id}.filtered_2.sam"

polypolish --version > versions.txt