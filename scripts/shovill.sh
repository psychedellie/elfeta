#!/usr/bin/env bash
set -euo pipefail

# Usage: shovill.sh <fq1> <fq2> <outdir> <threads> <mem_mb>
if [ $# -lt 5 ]; then
    echo "Usage: $0 <fq1> <fq2> <outdir> <threads> <mem_mb>" >&2
    exit 2
fi

# Assign arguments to variables
fq1="$1"
fq2="$2"
outdir="$3"
threads="$4"
mem_mb="$5"
args="${6:-}"

# Create output directory
mkdir -p "$outdir"

# Run Shovill assembler
shovill ${args} \
  --R1 "$fq1" \
  --R2 "$fq2" \
  --outdir "$outdir" \
  --force \
  --cpus "$threads" \
  --ram $((mem_mb / 1000)) 

  shovill --version > versions.txt