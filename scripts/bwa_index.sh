#!/usr/bin/env bash
set -euo pipefail

# Usage: bwa_index.sh <sample_id> <assembly> <output_dir>
if [ $# -lt 3 ]; then
    echo "Usage: $0 <sample_id> <assembly> <output_dir>" >&2
    exit 2
fi

# Variable Assignment
sample_id="$1"
assembly="$2"
out_dir="$3"

# Create Output Directory
mkdir -p "$out_dir"

# Run BWA Indexing
bwa-mem2 index -p "$sample_id" "$assembly"

# Move Index Files
mv "${sample_id}."* "$out_dir"