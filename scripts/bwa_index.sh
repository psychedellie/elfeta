#!/bin/bash
sample_id=$1
assembly=$2
out_dir=$3

bwa-mem2 index -p $sample_id $assembly

mv ${sample_id}.* $out_dir