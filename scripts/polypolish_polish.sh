#!/usr/bin/env bash
set -euo pipefail

# Usage: polypolish_polish.sh <sample_id> <assembly_in> <filtered_sam_1> <filtered_sam_2> [polypolish_args]
if [ $# -lt 4 ]; then
    echo "Usage: $0 <sample_id> <assembly_in> <filtered_sam_1> <filtered_sam_2> [polypolish_args]" >&2
    exit 2
fi

# Assign arguments to variables
sample_id="$1"
assembly_in="$2"
filtered_sam_1="$3"
filtered_sam_2="$4"
args="${5:-}"

# Define output file path
outdir="samples/${sample_id}/polypolish"
out_file="${outdir}/consensus.fasta"

# Create output directory
mkdir -p "$outdir"

# Run Polypolish polish
polypolish polish ${args} \
    "$assembly_in" \
    "$filtered_sam_1" \
    "$filtered_sam_2" \
    > "${out_file}"