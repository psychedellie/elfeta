#!/bin/bash
set -euo pipefail

consensus=$1
output=$2
species_name=${3:-}
threads=${4:-4}

# Detect AMRFinderPlus installation prefix (works for conda or mamba)
ENV_PREFIX=$(dirname "$(dirname "$(which amrfinder)")")
DB_DIR="$ENV_PREFIX/share/amrfinderplus/data/latest"

# --- Database check ---
if [ ! -d "$DB_DIR" ]; then
  echo "AMRFinderPlus database not found in: $DB_DIR"
  echo "Downloading latest database..."
  amrfinder -u || {
    echo "Failed to download AMRFinderPlus database."
    exit 1
  }
else
  echo "✅ AMRFinderPlus database found: $DB_DIR"
fi

# --- Run AMRFinderPlus ---
if [[ -n "$species_name" && "$species_name" != "Not_available_in_AMRFinderPlus" && "$species_name" != "Not_available" ]]; then
  echo "Running AMRFinder with species: $species_name"
  amrfinder -n "$consensus" -o "$output" -O "$species_name" --threads "$threads" --plus
else
  echo "⚠️  Invalid or unavailable species ($species_name) — running without species flag."
  amrfinder -n "$consensus" -o "$output" --threads "$threads" --plus
fi

