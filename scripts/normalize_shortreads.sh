#!/usr/bin/env bash
set -euo pipefail

# Usage: normalize_shortreads.sh <in_dir> <outdir>
if [ $# -lt 2 ]; then
    echo "Usage: $0 <in_dir> <outdir>" >&2
    exit 2
fi

# Assign required arguments to variables
in_dir="${1:?Input FASTQ dir required}"
outdir="${2:?Output dir required}"

# Create output directory and samples TSV file
mkdir -p "$outdir"
samples_tsv="$outdir/samples.tsv"
: > "$samples_tsv"

shopt -s nullglob extglob

# Collect all FASTQ files from the input directory
mapfile -t files < <(find "$in_dir" -type f \
  \( -iname "*.fastq" -o -iname "*.fastq.gz" -o -iname "*.fq" -o -iname "*.fq.gz" \) \
  | sort -V)

# Check if any FASTQ files were found
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No FASTQ files found in: $in_dir" >&2
  exit 1
fi

declare -A wrote_row

# Loop through each found file
for f in "${files[@]}"; do
  bn="$(basename "$f")"
  
  # Extract numeric ID and read direction (R1/R2) using regex
  if [[ "$bn" =~ ^([0-9]+).*_R([12]) ]]; then
    orig_id="${BASH_REMATCH[1]}"
    read_num="${BASH_REMATCH[2]}"
    
    # Define new paths for the normalized file
    new_name="${orig_id}_R${read_num}.fastq.gz"
    new_path="$outdir/$new_name"
    
    # Copy file to output directory with new name
    cp \
      "$f" \
      "$new_path"
    
    # Record unique sample ID in samples.tsv
    if [[ -z "${wrote_row[$orig_id]:-}" ]]; then
        printf "%s\t%s\n" "$orig_id" "${orig_id}" >> "$samples_tsv"
        wrote_row[$orig_id]=1
    fi
    
    # Log normalization action
    echo "Normalized: $bn → $new_name"
  fi
done

echo "Wrote: $samples_tsv"