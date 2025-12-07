#!/usr/bin/env bash
set -euo pipefail

# Usage: bakta.sh <consensus> <outdir> <sample_name> <threads> <db_path> [args]
if [ $# -lt 5 ]; then
    echo "Usage: $0 <consensus> <outdir> <sample_name> <threads> <db_path> [args]" >&2
    exit 2
fi

consensus="$1"
outdir="$2"
sample_name="$3"
threads="$4"
database="$5"
args="${6:-}"

mkdir -p "$outdir"

bakta ${args} \
      --output "$outdir" \
      --prefix "$sample_name" \
      --threads "$threads" \
      --db "$database" \
      "$consensus"

bakta --version > versions.txt

json_file="$database/bakta.db.json"

if [ ! -f "$json_file" ]; then
    json_file="$database/db-versions.json"
fi

if [ -f "$json_file" ]; then
    python3 -c "import json; data=json.load(open('$json_file')); print(f\"Date: {data.get('date', 'N/A')}\nType: {data.get('type', 'N/A')}\")" > db_version.txt
else
    # Fallback if JSON is missing
    echo "Database path used: $database" > db_version.txt
fi