#!/bin/bash

assembly=$1
output_dir=$2
raw_file_R1=$3
raw_file_R2=$4
threads=$5

# Run QUAST
quast $assembly -o $output_dir --pe1 $raw_file_R1 --pe2 $raw_file_R2 --threads $threads
