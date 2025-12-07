#!/usr/bin/env bash
set -euo pipefail

# Usage: plasmidfinder.sh <assembly> <out_dir> <db> [optional_args]
if [ $# -lt 3 ]; then
    echo "Usage: $0 <assembly> <out_dir> <db> [optional_args]" >&2
    exit 2
fi

# Assign required arguments to variables
consensus="$1"
outdir="$2"
database="$3"
args="${4:-}"

# Create outdir directory
mkdir -p "$outdir"

# Run PlasmidFinder with arguments
plasmidfinder.py ${args} \
    -i "$consensus" \
    -p "$database" \
    -o "$outdir"

# 2. Database Version
# Priority: Check for VERSION.txt inside the database folder
if [ -f "${database}/VERSION.txt" ]; then
    cp "${database}/VERSION.txt" db_version.txt
elif [ -f "${database}/version.txt" ]; then
    # Check lowercase just in case
    cp "${database}/version.txt" db_version.txt
elif [ -d "${database}/.git" ]; then
    # Fallback to git if no text file exists
    echo "Git Commit Hash:" > db_version.txt
    git -C "${database}" rev-parse HEAD >> db_version.txt
else
    # Final fallback
    echo "Database path used: ${database}" > db_version.txt
fi