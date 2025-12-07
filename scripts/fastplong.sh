#!/usr/bin/env bash
set -euo pipefail

# Usage: fastplong.sh <input_dir> <outdir> <threads>
if [ $# -lt 3 ]; then
    echo "Usage: $0 <input_dir> <outdir> <threads>" >&2
    exit 2
fi

input_dir="$1"
outdir="$2"
threads="$3"
args="${@:4}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_file="${outdir}/fastplong.log"

mkdir -p "$outdir"
mkdir -p "${outdir}/filtered_reads"

echo "[fastplong] Starting QC..."
echo "[fastplong] Input:  $input_dir"
echo "[fastplong] Output: $outdir"
echo "[fastplong] Threads: $threads" | tee -a "$log_file"

# skip existing
if compgen -G "${outdir}/filtered_reads/*.fastq.gz" > /dev/null; then
    echo "[fastplong] Filtered reads already present — skipping." | tee -a "$log_file"
    exit 0
fi

# run FastpLong directly (Nextflow already activates the env)
echo "[fastplong] Running FastpLong..." | tee -a "$log_file"

python "$script_dir/parallel_ont.py" \
    --input_dir "$input_dir" \
    --out_dir "$outdir" \
    --thread "$threads" \
    --args="$args" \
    2>&1 | tee -a "$log_file"

fastplong --version > versions.txt

# organize outputs
echo "[fastplong] Organizing output files..." | tee -a "$log_file"

# move reads
if compgen -G "${outdir}/*.fastq.gz" > /dev/null; then
    mv "${outdir}"/*.fastq.gz "${outdir}/filtered_reads/" 2>/dev/null || true
fi

# ensure reports stay at top-level
for f in "${outdir}"/*.html "${outdir}"/*.json; do
    [ -f "$f" ] && echo "[fastplong] Found report: $(basename "$f")" | tee -a "$log_file"
done

echo "[fastplong] Done." | tee -a "$log_file"
