#!/usr/bin/env bash
set -euo pipefail

# ======================================================
#   MERGE FASTQS SCRIPT (final version)
#   - Merges barcode FASTQs or single FASTQs
#   - Renames output using sample sheet (Lab_ID, Original_ID, Index)
#   - Safe for missing columns and Windows CSVs
#   - Fixes octal error for Index values (e.g. 08, 09)
# ======================================================

input_dir="$1"
output_dir="$2"
sample_sheet="$3"

mkdir -p "$output_dir"

echo "[merge_fastqs] ======================================="
echo "[merge_fastqs] Input dir: $input_dir"
echo "[merge_fastqs] Output dir: $output_dir"
echo "[merge_fastqs] Sample sheet: $sample_sheet"
echo "[merge_fastqs] ======================================="

# ------------------------------------------------------
# Load mapping from sample sheet if it exists
# ------------------------------------------------------
declare -A name_map

if [[ -f "$sample_sheet" ]]; then
    echo "[merge_fastqs] Parsing sample sheet: $sample_sheet"

    # Remove possible Windows CR and parse CSV
    while IFS=, read -r Lab_ID Original_ID Index Platform Rest; do
        # Skip header
        [[ "$Lab_ID" == "Lab_ID" ]] && continue
        [[ -z "$Index" ]] && continue

        # Force base-10 interpretation (avoids octal error on 08, 09)
        bc_index=$((10#$Index))
        bc=$(printf "barcode%02d" "$bc_index")

        # Build sample name safely (avoid extra underscores)
        if [[ -n "$Original_ID" && -n "$Lab_ID" ]]; then
            new_name="${Original_ID}_${Lab_ID}"
        elif [[ -n "$Original_ID" ]]; then
            new_name="${Original_ID}"
        elif [[ -n "$Lab_ID" ]]; then
            new_name="${Lab_ID}"
        else
            new_name="$bc"
        fi

        name_map["$bc"]="$new_name"
        echo "[merge_fastqs] Map: $bc → $new_name"

    done < <(tr -d '\r' < "$sample_sheet")
else
    echo "[merge_fastqs] WARNING: Sample sheet not found, using default barcode names"
fi

# ------------------------------------------------------
# Case 1: demultiplexed by barcode directories
# ------------------------------------------------------
if compgen -G "${input_dir}/barcode*" > /dev/null; then
    echo "[merge_fastqs] Detected barcode directories"

    for barcode in "${input_dir}"/barcode*; do
        [ -d "$barcode" ] || continue
        barcode_name=$(basename "$barcode")

        # Lookup mapping, fallback to barcode if missing
        new_name="${name_map[$barcode_name]:-$barcode_name}"
        merged="${output_dir}/${new_name}.fastq.gz"

        echo "[merge_fastqs] Merging reads for ${barcode_name} → ${new_name}"
        cat "${barcode}"/*.fastq.gz > "$merged"
    done

# ------------------------------------------------------
# Case 2: direct FASTQ files
# ------------------------------------------------------
else
    fastqs=("${input_dir}"/*.fastq.gz)
    if [ ${#fastqs[@]} -eq 0 ]; then
        echo "[merge_fastqs] ERROR: No .fastq.gz files found in ${input_dir}" >&2
        exit 1
    elif [ ${#fastqs[@]} -eq 1 ]; then
        echo "[merge_fastqs] Single FASTQ detected — copying directly"
        cp "${fastqs[0]}" "${output_dir}/$(basename "${fastqs[0]}")"
    else
        echo "[merge_fastqs] Multiple FASTQs detected — merging"
        cat "${fastqs[@]}" > "${output_dir}/merged.fastq.gz"
    fi
fi

echo "[merge_fastqs] Done."
echo "[merge_fastqs] ======================================="
