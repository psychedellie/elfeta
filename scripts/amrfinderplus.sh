#!/bin/bash
set -euo pipefail

# Arguments: consensus output species [threads]
consensus=$1
output=$2
species_name=${3:-}
threads=${4:-4}
database=$5

if [[ -n "${species_name}" && "${species_name}" != "Not_available_in_AMRFinderPlus" && "${species_name}" != "Not_available" ]]; then
    amrfinder -n "${consensus}" -o "${output}" -O "${species_name}" --threads "${threads}" --plus --database "${database}"
else
    amrfinder -n "${consensus}" -o "${output}" --threads "${threads}" --plus --database "${database}"
fi
