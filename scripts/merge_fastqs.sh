#!/usr/bin/env bash
set -euo pipefail

# scripts/merge_fastqs.sh
# Merge ONT FASTQs by barcode, filtered by CSV (Lab_ID, Index).
# Usage: scripts/merge_fastqs.sh <input_dir> <output_dir> <sample_sheet.csv>

input_dir=$1
output_dir=$2
sample_sheet=$3

mkdir -p "$output_dir"
echo "[merge_fastqs] ======================================="
echo "[merge_fastqs] Input dir: $input_dir"
echo "[merge_fastqs] Output dir: $output_dir"
echo "[merge_fastqs] Sample sheet: $sample_sheet"
echo "[merge_fastqs] ======================================="

# Validate header (expect Lab_ID in col1 and Index in col3)
header=$(head -n1 "$sample_sheet" | tr -d '\r')
IFS=, read -r lab_id _ index _ <<< "$header"
# Handle potential BOM character at the start of the file
lab_id_clean=$(echo "$lab_id" | sed -e 's/^\xEF\xBB\xBF//' | tr '[:upper:]' '[:lower:]')
index_clean=$(echo "$index" | tr '[:upper:]' '[:lower:]')

if [[ "$lab_id_clean" != "lab_id" || "$index_clean" != "index" ]]; then
  echo "ERROR: Sample sheet must have Lab_ID in first column and Index in third"
  echo "  (Got '$lab_id_clean' and '$index_clean')"
  exit 1
fi

# Check for duplicate Lab_IDs
dups=$(tail -n +2 "$sample_sheet" | tr -d '\r' | cut -d, -f1 | sort | uniq -d)
if [ -n "$dups" ]; then
  echo "ERROR: Duplicate Lab_IDs in sample sheet:"
  echo "$dups" | sed 's/^/  - /'
  exit 1
fi

echo "[merge_fastqs] Header OK. Starting merge..."

# Merge loop: use col1 (Lab_ID) and col3 (Index)
# Read from tail, remove carriage returns
tail -n +2 "$sample_sheet" | tr -d '\r' | while IFS=, read -r isolate _ barcode _; do
  # Trim whitespace
  barcode="$(echo "$barcode" | xargs)"
  isolate="$(echo "$isolate" | xargs)"
  
  # Skip empty lines or lines without a barcode
  [ -z "$barcode" ] && continue
  [ -z "$isolate" ] && continue

  # Force base-10 interpretation (avoids octal error on 08, 09)
  bc_index=$((10#$barcode))
  barcode_folder=$(printf "barcode%02d" "$bc_index")

  # Check for src directory (original script had $barcode and barcode$barcode, this is safer)
  if [ -d "$input_dir/$barcode_folder" ]; then
    src_dir="$input_dir/$barcode_folder"
  elif [ -d "$input_dir/$barcode" ]; then
    src_dir="$input_dir/$barcode"
  else
    echo "WARN: No folder for barcode $barcode (checked $barcode_folder and $barcode)"
    continue
  fi

  shopt -s nullglob
  files=( "$src_dir"/*.fastq.gz "$src_dir"/*.fq.gz )
  shopt -u nullglob
  [ ${#files[@]} -eq 0 ] && { echo "WARN: No FASTQs in $src_dir"; continue; }

  out="$output_dir/${isolate}.fastq.gz"
  
  echo "[merge_fastqs] Merging ${#files[@]} files from $src_dir -> $out"
  printf "%s\n" "${files[@]}" | sort -V | xargs -r cat -- > "$out"

  if command -v zcat >/dev/null 2>&1; then
    reads=$(zcat "$out" | awk 'NR%4==1{c++} END{print c+0}')
    echo "OK: $barcode ($src_dir) -> $out ($reads reads)"
  else
    echo "OK: $barcode ($src_dir) -> $out"
  fi
done

echo "[merge_fastqs] Done."