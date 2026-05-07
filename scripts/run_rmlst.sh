#!/usr/bin/env bash
set -euo pipefail

# Usage: run_rmlst.sh <consensus> <rmlst_out> <org_file> <species_file> [args]
if [ $# -lt 4 ]; then
    echo "Usage: $0 <consensus> <rmlst_out> <org_file> <species_file> [args]" >&2
    exit 2
fi

consensus="$1"
rmlst="$2"
organism_file="$3"
species_file="$4"
shift 4

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

mkdir -p "$(dirname "$rmlst")"
mkdir -p "$(dirname "$species_file")" 2>/dev/null || true

# Total wall-time cap (seconds). Change via env var if you want.
RMLST_WALLTIME="${RMLST_WALLTIME:-300}"   # default 5 minutes

fallback_outputs () {
  # minimal valid TSV with header
  printf "Rank\tTaxon\tSupport\tTaxonomy\tGenus\tSpecies\tAbbreviated\n" > "$rmlst"
  # species label file
  echo "Not_available" > "$species_file"
}

# If GNU timeout exists, hard-cap the whole python call
if command -v timeout >/dev/null 2>&1; then
  set +e
  timeout --signal=TERM "${RMLST_WALLTIME}" \
    python "$script_dir/rmlst.py" \
      -f "$consensus" \
      -o "$rmlst" \
      -O "$organism_file" \
      --species_file "$species_file" \
      "$@"
  status=$?
  set -e

  # 124/137 = timeout/killed
  if [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; then
    echo "[rMLST] WARNING: exceeded ${RMLST_WALLTIME}s; writing fallback outputs." >&2
    fallback_outputs
    exit 0
  fi

  # Any other non-zero = also fallback (prevents pipeline failure)
  if [ "$status" -ne 0 ]; then
    echo "[rMLST] WARNING: failed (exit $status); writing fallback outputs." >&2
    fallback_outputs
    exit 0
  fi
else
  # No timeout installed: run normally; still fallback on failure
  set +e
  python "$script_dir/rmlst.py" \
      -f "$consensus" \
      -o "$rmlst" \
      -O "$organism_file" \
      --species_file "$species_file" \
      "$@"
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    echo "[rMLST] WARNING: failed (exit $status); writing fallback outputs." >&2
    fallback_outputs
    exit 0
  fi
fi