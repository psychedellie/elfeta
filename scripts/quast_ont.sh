#!/usr/bin/env bash
set -euo pipefail

# Usage: quast.sh <assembly> <outdir> <fastq> <threads> [optional_args]
if [ $# -lt 4 ]; then
    echo "Usage: $0 <assembly> <outdir> <fastq> <threads> [optional_args]" >&2
    exit 2
fi

# Assign required arguments to variables
assembly="$1"
outdir="$2"
np_raw_file="$3"
threads="$4"
args="${5:-}"

# Create output directory
mkdir -p "$outdir"

# Run QUAST with Nanopore data
quast ${args} \
    "$assembly" \
    -o "$outdir" \
    --nanopore "$np_raw_file" \
    -t "$threads"