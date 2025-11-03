results_dir=$1
sample_sheet=$2
quast_dir=$3
mlst_dir=$4
rmlst_dir=$5
plasmidfinder_dir=$6
amrfinder_dir=$7

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

Rscript "$SCRIPT_DIR/NGS_Report_v2.1.R" $results_dir $sample_sheet $quast_dir $mlst_dir $rmlst_dir $plasmidfinder_dir $amrfinder_dir