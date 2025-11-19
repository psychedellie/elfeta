#!/usr/bin/env bash
set -euo pipefail

# Usage: quast.sh <assembly> <output_dir> <raw_file_R1> <raw_file_R2> <threads>
if [ $# -lt 5 ]; then
    echo "Usage: $0 <assembly> <output_dir> <raw_file_R1> <raw_file_R2> <threads>" >&2
    exit 2
fi

# Assign arguments to variables
assembly="$1"
output_dir="$2"
raw_file_R1="$3"
raw_file_R2="$4"
threads="$5"

# Create output directory
mkdir -p "$output_dir"

# Run QUAST with short-read correction
quast "$assembly" \
    -o "$output_dir" \
    --pe1 "$raw_file_R1" \
    --pe2 "$raw_file_R2" \
    --threads "$threads"