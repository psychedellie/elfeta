process REPORT {
    tag "Generating run report"
    label 'report'
    conda "${params.envs_dir}/r-report.yaml"
    publishDir "${params.outdir}", mode: 'copy'

    input:
        path results_dir
        path sample_sheet

    output:
        path("final_report_complete.xlsx"), emit: rep

    script:
    """
    mkdir -p report_tmp/Results
    echo "[REPORT] Running report.sh inside: \$(pwd)"

    bash ${params.scripts_dir}/report.sh \
        "report_tmp/Results" \
        "${sample_sheet}" \
        "report_tmp/Results/QUAST" \
        "report_tmp/Results/MLST" \
        "report_tmp/Results/rMLST" \
        "report_tmp/Results/PlasmidFinder" \
        "report_tmp/Results/AMRFinderPlus" \
        "report_tmp/Results/Bakta"

    echo "[REPORT] Moving output Excel file back to root..."
    mv report_tmp/Results/final_report_complete.xlsx . || (echo "No file generated!" && ls -R && exit 1)
    """
}
