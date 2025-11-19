#!/usr/bin/env bash
set -euo pipefail

# Usage: fastp.sh <input_dir> <output_dir> <threads> [optional_fastp_args]
if [ $# -lt 3 ]; then
    echo "Usage: $0 <input_dir> <output_dir> <threads> [args]" >&2
    exit 2
fi

input_dir="$1"
output_dir="$2"
threads="$3"
args="${4:-}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_file="${output_dir}/fastp.log"

mkdir -p "$output_dir"
mkdir -p "${output_dir}/filtered_reads"

echo "[fastp] Starting QC..."
echo "[fastp] Input:  $input_dir"
echo "[fastp] Output: $output_dir"
echo "[fastp] Threads: $threads" | tee -a "$log_file"

# skip existing
# Note: compgen checks if files exist to avoid globbing errors later
if compgen -G "${output_dir}/filtered_reads/*.hq.fastq.gz" > /dev/null; then
    echo "[fastp] Filtered reads already present — skipping." | tee -a "$log_file"
    exit 0
fi

# run fastp directly (Nextflow already activates the env)
echo "[fastp] Running fastp..." | tee -a "$log_file"

if [ ! -f "$script_dir/parallel_iln.py" ]; then
    echo "Error: Python script not found at $script_dir/parallel_iln.py" | tee -a "$log_file"
    exit 1
fi

python "$script_dir/parallel_iln.py" \
    --input_dir "$input_dir" \
    --out_dir "$output_dir" \
    --thread "$threads" \
    --args '$args' \
    2>&1 | tee -a "$log_file"

# organize outputs
echo "[fastp] Organizing output files..." | tee -a "$log_file"

# move reads (changed from *.fastq.gz to *.hq.fastq.gz)
# The 'if' prevents 'mv' from failing if the python script didn't generate files
if compgen -G "${output_dir}/*.hq.fastq.gz" > /dev/null; then
    mv "${output_dir}"/*.hq.fastq.gz "${output_dir}/filtered_reads/" 2>/dev/null || true
fi

# ensure reports stay at top-level
for f in "${output_dir}"/*.html "${output_dir}"/*.json; do
    [ -f "$f" ] && echo "[fastp] Found report: $(basename "$f")" | tee -a "$log_file"
done

echo "[fastp] Done." | tee -a "$log_file"