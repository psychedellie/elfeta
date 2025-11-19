#!/usr/bin/env bash
set -euo pipefail

# Usage: fastplong.sh <input_dir> <output_dir> <threads>
if [ $# -lt 3 ]; then
    echo "Usage: $0 <input_dir> <output_dir> <threads>" >&2
    exit 2
fi

input_dir="$1"
output_dir="$2"
threads="$3"
args="${4:-}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_file="${output_dir}/fastplong.log"

mkdir -p "$output_dir"
mkdir -p "${output_dir}/filtered_reads"

echo "[fastplong] Starting QC..."
echo "[fastplong] Input:  $input_dir"
echo "[fastplong] Output: $output_dir"
echo "[fastplong] Threads: $threads" | tee -a "$log_file"

# skip existing
if compgen -G "${output_dir}/filtered_reads/*.fastq.gz" > /dev/null; then
    echo "[fastplong] Filtered reads already present — skipping." | tee -a "$log_file"
    exit 0
fi

# run FastpLong directly (Nextflow already activates the env)
echo "[fastplong] Running FastpLong..." | tee -a "$log_file"

python "$script_dir/parallel_ont.py" \
    --input_dir "$input_dir" \
    --out_dir "$output_dir" \
    --thread "$threads" \
    --args '$args' \
    2>&1 | tee -a "$log_file"

# organize outputs
echo "[fastplong] Organizing output files..." | tee -a "$log_file"

# move reads
if compgen -G "${output_dir}/*.fastq.gz" > /dev/null; then
    mv "${output_dir}"/*.fastq.gz "${output_dir}/filtered_reads/" 2>/dev/null || true
fi

# ensure reports stay at top-level
for f in "${output_dir}"/*.html "${output_dir}"/*.json; do
    [ -f "$f" ] && echo "[fastplong] Found report: $(basename "$f")" | tee -a "$log_file"
done

echo "[fastplong] Done." | tee -a "$log_file"
