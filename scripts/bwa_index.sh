#!/usr/bin/env bash
set -euo pipefail

# Usage: bwa_index.sh <sample_id> <assembly> <outdir>
if [ $# -lt 3 ]; then
    echo "Usage: $0 <sample_id> <assembly> <outdir>" >&2
    exit 2
fi

# Variable Assignment
sample_id="$1"
assembly="$2"
outdir="$3"
args="${4:-}"

# Create Output Directory
mkdir -p "$outdir"

# Run BWA Indexing
bwa-mem2 index ${args} \
    -p "$sample_id" \
    "$assembly"

# Move Index Files
mv "${sample_id}."* "$outdir"