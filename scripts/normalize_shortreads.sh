#!/usr/bin/env bash
set -euo pipefail

# Normalize Illumina FASTQ names to <num>_ILN with per-sample subfolders.
# NO CONCATENATION: lane/part files become ..._R1_1.fastq.gz, ..._R1_2.fastq.gz, etc.
#
# Usage:
#   scripts/normalize_shortreads.sh <input_fastq_dir> <output_dir>
#
# Input patterns supported (gz or not), e.g.:
#   457_S36_R1.fastq.gz
#   457_S36_R2_L0001.fastq.gz
#   457_S36_L0002_R1_001.fastq
#   457_R1.fq.gz
#   457_R2_001.fq

in_dir=${1:? "Input FASTQ dir required"}
out_dir=${2:? "Output dir required"}

mkdir -p "$out_dir"
samples_tsv="$out_dir/samples.tsv"
: > "$samples_tsv"

shopt -s nullglob extglob

# collect fastqs
mapfile -t files < <(find "$in_dir" -type f \
  \( -iname "*.fastq" -o -iname "*.fastq.gz" -o -iname "*.fq" -o -iname "*.fq.gz" \) \
  | sort -V)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No FASTQ files found in: $in_dir" >&2
  exit 1
fi

get_ext() {
  local f="$1"
  if [[ "$f" =~ \.fastq\.gz$ ]]; then echo ".fastq.gz"
  elif [[ "$f" =~ \.fq\.gz$ ]]; then echo ".fq.gz"
  elif [[ "$f" =~ \.fastq$ ]]; then echo ".fastq"
  elif [[ "$f" =~ \.fq$ ]]; then echo ".fq"
  else echo ""; fi
}

get_read_dir() {
  local base="$1"; local up="${base^^}"
  if [[ "$up" =~ (^|[_\.])R1([^0-9]|$) ]] || [[ "$up" =~ (^|[_\.])1([^0-9]|$) ]]; then echo "R1"; return; fi
  if [[ "$up" =~ (^|[_\.])R2([^0-9]|$) ]] || [[ "$up" =~ (^|[_\.])2([^0-9]|$) ]]; then echo "R2"; return; fi
  echo ""
}

declare -A wrote_row
declare -A counter

for f in "${files[@]}"; do
  bn="$(basename "$f")"
  ext="$(get_ext "$bn")"
  base="${bn%$ext}"

  # leading numeric id
  if [[ "$base" =~ ^([0-9]+) ]]; then
    orig_id="${BASH_REMATCH[1]}"
  else
    continue
  fi

  read_dir="$(get_read_dir "$base")"
  [[ -z "$read_dir" ]] && continue

  normalized="${orig_id}_ILN"
  sample_dir="$out_dir/$normalized"
  mkdir -p "$sample_dir"

  if [[ -z "${wrote_row[$orig_id]:-}" ]]; then
    printf "%s\t%s\n" "$orig_id" "$normalized" >> "$samples_tsv"
    wrote_row[$orig_id]=1
  fi

  key="${normalized}_${read_dir}"
  n=$(( ${counter[$key]:-0} + 1 ))
  counter[$key]=$n

  # keep gz if present; if plain .fastq/.fq, do not compress here—just preserve ext
  out_ext="$ext"
  out="${sample_dir}/${normalized}_${read_dir}_${n}${out_ext}"

  # make a stable relative symlink
  cp -n "$f" "$out"
done

echo "Wrote: $samples_tsv"
