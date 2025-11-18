#!/usr/bin/env bash
set -euo pipefail

# 1. Receive all 5 arguments
sample_id=$1
assembly_in=$2
filtered_sam_1=$3
filtered_sam_2=$4
polypolish_args=$5

# 2. Define output file
out_dir="samples/${sample_id}"
out_file="${out_dir}/consensus.fasta"

# 3. Create output directory
mkdir -p "${out_dir}"

# 4. Run Polypolish with the TWO sam files
polypolish polish ${polypolish_args} "${assembly_in}" "${filtered_sam_1}" "${filtered_sam_2}" > "${out_file}"