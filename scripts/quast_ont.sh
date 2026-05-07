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

# Remove the first 5 positional arguments ($1 through $5)
# What remains in $@ are the optional QUAST arguments
shift 4

# The remaining arguments are now in $@
args="$@"

# Create output directory
mkdir -p "$outdir"

# Run QUAST with Nanopore data
quast ${args} \
    "$assembly" \
    -o "$outdir" \
    --nanopore "$np_raw_file" \
    -t "$threads"

quast --version > versions.txt