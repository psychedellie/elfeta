#!/usr/bin/env bash
set -euo pipefail

in_dir=${1:? "Input FASTQ dir required"}
out_dir=${2:? "Output dir required"}

mkdir -p "$out_dir"
samples_tsv="$out_dir/samples.tsv"
: > "$samples_tsv"

shopt -s nullglob extglob

# collect fastqs from input directory
mapfile -t files < <(find "$in_dir" -type f \
  \( -iname "*.fastq" -o -iname "*.fastq.gz" -o -iname "*.fq" -o -iname "*.fq.gz" \) \
  | sort -V)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No FASTQ files found in: $in_dir" >&2
  exit 1
fi

declare -A wrote_row

for f in "${files[@]}"; do
  bn="$(basename "$f")"
  
  # Extract numeric ID and read direction (R1/R2)
  if [[ "$bn" =~ ^([0-9]+).*_R([12]) ]]; then
    orig_id="${BASH_REMATCH[1]}"
    read_num="${BASH_REMATCH[2]}"
    
    # Create new filename: 447_R1.fastq.gz
    new_name="${orig_id}_R${read_num}.fastq.gz"
    new_path="$out_dir/$new_name"
    
    # Copy file to output directory with new name
    cp "$f" "$new_path"
    
    # Record in samples.tsv
    if [[ -z "${wrote_row[$orig_id]:-}" ]]; then
        printf "%s\t%s\n" "$orig_id" "${orig_id}" >> "$samples_tsv"
        wrote_row[$orig_id]=1
    fi
    
    echo "Normalized: $bn → $new_name"
  fi
done

echo "Wrote: $samples_tsv"