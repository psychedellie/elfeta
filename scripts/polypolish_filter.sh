
#!/usr/bin/env bash
set -euo pipefail

sam1=$1
sam2=$2
sample_id=$3

polypolish filter --in1 ${sam1} --in2 ${sam2} --out1 ${sample_id}.filtered_1.sam --out2 ${sample_id}.filtered_2.sam