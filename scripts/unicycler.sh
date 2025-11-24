#!/usr/bin/env bash
set -euo pipefail

# Usage: shovill.sh <fq1> <fq2> <long_reads> <outdir> <threads> [extra_args]
if [ $# -lt 5 ]; then
    echo "Usage: $0 <fq1> <fq2> <long> <outdir> <threads> [args]" >&2
    exit 2
fi

# Assign arguments to variables
fq1="$1"
fq2="$2"
long="$3"
outdir="$4"
threads="$5"
args="${@:6}"

# Create output directory
mkdir -p "$outdir"

# Run Shovill assembler
unicycler ${args[@]} \
  --short1 "$fq1" \
  --short2 "$fq2" \
  --long "$long" \
  --out "$outdir" \
  --threads "$threads" 