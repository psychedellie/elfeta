#!/usr/bin/env bash
set -euo pipefail

# Usage: quast.sh <assembly> <out_dir> <fastq> <threads> [optional_args]
if [ $# -lt 4 ]; then
    echo "Usage: $0 <assembly> <out_dir> <fastq> <threads> [optional_args]" >&2
    exit 2
fi

# Assign required arguments to variables
assembly="$1"
output_dir="$2"
np_raw_file="$3"
threads="$4"
args="${5:-}"

# Create output directory
mkdir -p "$output_dir"

# Run QUAST with Nanopore data
quast "$assembly" \
    -o "$output_dir" \
    --nanopore "$np_raw_file" \
    -t "$threads" \
    $args