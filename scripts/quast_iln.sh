#!/usr/bin/env bash
set -euo pipefail

# Usage: quast.sh <assembly> <outdir> <raw_file_R1> <raw_file_R2> <threads> [optional_quast_args]
if [ $# -lt 5 ]; then
    echo "Usage: $0 <assembly> <outdir> <raw_file_R1> <raw_file_R2> <threads> [optional_quast_args]" >&2
    exit 2
fi

# Assign arguments to variables
assembly="$1"
outdir="$2"
raw_file_R1="$3"
raw_file_R2="$4"
threads="$5"

# Remove the first 5 positional arguments ($1 through $5)
# What remains in $@ are the optional QUAST arguments
shift 5

# The remaining arguments are now in $@
args="$@"

# Create output directory
mkdir -p "$outdir"

# Run QUAST with short-read correction
quast "$assembly" \
    -o "$outdir" \
    --pe1 "$raw_file_R1" \
    --pe2 "$raw_file_R2" \
    --threads "$threads" \
    $args # Unquoted to allow expansion of multiple arguments

quast --version > versions.txt