#!/usr/bin/env bash
set -euo pipefail

# Usage: amrfinderplus.sh <assembly> <output> <threads> <species> <database> [args]
if [ $# -lt 5 ]; then
    echo "Usage: $0 <assembly> <output> <threads> <species> <database> [args]" >&2
    exit 2
fi

consensus="$1"
output="$2"
threads="$3"
species_name="$4"
database="$5"
args="${6:-}"

mkdir -p "$(dirname "$output")"

# Determine organism flag
org_flag=""
if [[ -n "${species_name}" && "${species_name}" != "null" && "${species_name}" != "Not_available_in_AMRFinderPlus" && "${species_name}" != "Not_available" ]]; then
    org_flag="-O \"${species_name}\""
fi

# Run AMRFinderPlus
# Note: --database argument is required if using a custom DB path
if [ -n "$org_flag" ]; then
    amrfinder ${args} \
    -n "$consensus" \
    -o "$output" \
    --threads "$threads" \
    --database "$database" \
    -O "$species_name"
else
    amrfinder ${args} \
    -n "$consensus" \
    -o "$output" \
    --threads "$threads" \
    --database "$database"
fi