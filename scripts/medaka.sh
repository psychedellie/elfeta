#!/bin/bash
set -e

np_raw_file=$1
assembly=$2
output_dir=$3
threads=$4
model=$5

echo "medaka.sh DEBUG:"
echo "Input file: $np_raw_file"
echo "Assembly: $assembly"
echo "Output dir: $output_dir"
echo "Threads: $threads"
echo "Model: $model"

if [ -d $output_dir ]; then
    echo "Deleting existing folder: $output_dir"
    rm -rf $output_dir
fi

micromamba run -n medaka medaka_consensus -i $np_raw_file -d $assembly -o $output_dir -t $threads --bacteria -m $model