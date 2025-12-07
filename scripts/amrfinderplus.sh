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

    amrfinder --version > versions.txt
else
    amrfinder ${args} \
    -n "$consensus" \
    -o "$output" \
    --threads "$threads" \
    --database "$database"

    amrfinder --version > versions.txt
fi

# --- NEW: Capture Database Version ---
if [ -f "${database}/version.txt" ]; then
    cp "${database}/version.txt" db_version.txt
else
    # Fallback: Record the database path if no version file is found
    echo "Database path used: ${database}" > db_version.txt
fi