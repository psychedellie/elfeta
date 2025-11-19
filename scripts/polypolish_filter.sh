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

# Run Polypolish filter
polypolish filter \
    --in1 "${sam1}" \
    --in2 "${sam2}" \
    --out1 "${sample_id}.filtered_1.sam" \
    --out2 "${sample_id}.filtered_2.sam"