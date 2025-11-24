#!/usr/bin/env bash
set -euo pipefail

# Usage: merge_fastqs.sh <input_dir> <outdir> <sample_sheet.csv>
if [ $# -lt 3 ]; then
    echo "Usage: $0 <input_dir> <outdir> <sample_sheet.csv>" >&2
    exit 2
fi

# Assign arguments to variables
input_dir="$1"
outdir="$2"
sample_sheet="$3"

# Create output directory
mkdir -p "$outdir"

# --- Header Validation ---
header=$(head -n1 "$sample_sheet" | tr -d '\r')
IFS=, read -r lab_id _ index _ <<< "$header"

# Clean and validate header columns
lab_id_clean=$(echo "$lab_id" | sed -e 's/^\xEF\xBB\xBF//' | tr '[:upper:]' '[:lower:]')
index_clean=$(echo "$index" | tr '[:upper:]' '[:lower:]')

if [[ "$lab_id_clean" != "lab_id" || "$index_clean" != "index" ]]; then
  echo "ERROR: Sample sheet must have Lab_ID in first column and Index in third"
  exit 1
fi

# Check for duplicate Lab_IDs
dups=$(tail -n +2 "$sample_sheet" | tr -d '\r' | cut -d, -f1 | sort | uniq -d)
if [ -n "$dups" ]; then
  echo "ERROR: Duplicate Lab_IDs in sample sheet:"
  echo "$dups"
  exit 1
fi

# --- Main Merge Loop ---
# Loop over sample sheet, reading Lab_ID (col1) and Index (col3)
tail -n +2 "$sample_sheet" | tr -d '\r' | while IFS=, read -r isolate _ barcode _; do
  # Trim whitespace from variables
  barcode="$(echo "$barcode" | xargs)"
  isolate="$(echo "$isolate" | xargs)"
  
  # Skip empty lines
  [ -z "$barcode" ] && continue
  [ -z "$isolate" ] && continue

  # Format barcode folder name (e.g., barcode01)
  bc_index=$((10#$barcode))
  barcode_folder=$(printf "barcode%02d" "$bc_index")

  # Determine source directory (checks standard and numeric names)
  if [ -d "$input_dir/$barcode_folder" ]; then
    src_dir="$input_dir/$barcode_folder"
  elif [ -d "$input_dir/$barcode" ]; then
    src_dir="$input_dir/$barcode"
  else
    continue
  fi

  # Find all fastq.gz files in the source directory
  shopt -s nullglob
  files=( "$src_dir"/*.fastq.gz "$src_dir"/*.fq.gz )
  shopt -u nullglob
  [ ${#files[@]} -eq 0 ] && { continue; }

  out="$outdir/${isolate}.fastq.gz"
  
  # Sort files and concatenate them into the final output file
  printf "%s\n" "${files[@]}" | sort -V | xargs -r cat -- > "$out"

  # Count reads and report success
  if command -v zcat >/dev/null 2>&1; then
    reads=$(zcat "$out" | awk 'NR%4==1{c++} END{print c+0}')
  fi
done