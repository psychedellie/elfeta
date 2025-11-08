#!/usr/bin/env bash
fq1=$1
fq2=$2
outdir=$3
threads=$4
mem_mb=$5

shovill \
  --R1 "$fq1" \
  --R2 "$fq2" \
  --outdir "$outdir" \
  --force \
  --cpus "$threads" \
  --ram $((mem_mb / 1000))
