#!/usr/bin/env bash
set -euo pipefail

# Usage: run_rmlst.sh <consensus> <rmlst_out> <org_file> <species_file> [args]
if [ $# -lt 4 ]; then
    echo "Usage: $0 <consensus> <rmlst_out> <org_file> <species_file> [args]" >&2
    exit 2
fi

# Assign arguments to variables
consensus="$1"
rmlst="$2"
organism_file="$3"
species_file="$4"

# Determine the absolute path of the script directory
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Create output directory
mkdir -p "$(dirname "$rmlst")"

# Run the rMLST Python script
python "$script_dir/rmlst.py" \
    -f "$consensus" \
    -o "$rmlst" \
    -O "$organism_file" \
    --species_file "$species_file"