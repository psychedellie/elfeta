#!/usr/bin/env bash
set -euo pipefail

# Usage: bwa_mem.sh <sample_id> <idx_prefix> <r1> <r2> <threads>
if [ $# -lt 5 ]; then
    echo "Usage: $0 <sample_id> <idx_prefix> <r1> <r2> <threads>" >&2
    exit 2
fi

# Assign arguments to variables
sample_id="$1"
idx_prefix="$2"
r1="$3"
r2="$4"
threads="$5"

# Create output directory for the sample
mkdir -p "samples/${sample_id}"

# Align R1 reads using bwa-mem2
bwa-mem2 mem \
    -t "${threads}" \
    -a "${idx_prefix}" \
    "${r1}" \
    > "samples/${sample_id}/${sample_id}_1.sam"

# Align R2 reads using bwa-mem2
bwa-mem2 mem \
    -t "${threads}" \
    -a "${idx_prefix}" \
    "${r2}" \
    > "samples/${sample_id}/${sample_id}_2.sam"