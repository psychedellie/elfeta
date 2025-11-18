#!/usr/bin/env bash
set -euo pipefail

sample_id=$1
index_prefix=$2
r1=$3
r2=$4
threads=$5

# 1. Create the directory that the Nextflow 'output' block expects
mkdir -p "samples/${sample_id}"

# 2. Write the SAM files into that directory
bwa-mem2 mem -t ${threads} -a ${index_prefix} ${r1} > "samples/${sample_id}/${sample_id}_1.sam"
bwa-mem2 mem -t ${threads} -a ${index_prefix} ${r2} > "samples/${sample_id}/${sample_id}_2.sam"