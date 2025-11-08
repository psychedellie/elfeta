process REPORT {
    tag "Generating run report"
    label 'report'
    conda "${params.envs_dir}/r-report.yaml"
    publishDir "${params.outdir}", mode: 'copy'

    input:
        path results_dir
        path sample_sheet
        val completion_trigger  // This ensures we wait for pipeline completion
        val mode                // This is the 'params.mode' (e.g., "ont")

    output:
        path("final_report_complete.xlsx"), emit: rep

    script:
    """
    echo "[REPORT] Running R script: NGS_Report_v2.1.R"
    echo "[REPORT] Using results directory: ${results_dir}"
    echo "[REPORT] Using sample sheet: ${sample_sheet}"

    # Define the 7 arguments for the R script
    ARG1_RESULTS_DIR="${results_dir}"
    ARG2_SAMPLE_SHEET="${sample_sheet}"
    ARG3_QUAST_DIR="${results_dir}/QUAST"
    ARG4_MLST_DIR="${results_dir}/MLST"
    ARG5_RMLST_DIR="${results_dir}/rMLST"
    ARG6_PLASMID_DIR="${results_dir}/PlasmidFinder"
    ARG7_AMR_DIR="${results_dir}/AMRFinderPlus"

    # Call the R script directly with exactly 7 arguments
    Rscript "${params.scripts_dir}/NGS_Report_v2.1.R" \
        "\$ARG1_RESULTS_DIR" \
        "\$ARG2_SAMPLE_SHEET" \
        "\$ARG3_QUAST_DIR" \
        "\$ARG4_MLST_DIR" \
        "\$ARG5_RMLST_DIR" \
        "\$ARG6_PLASMID_DIR" \
        "\$ARG7_AMR_DIR"

    echo "[REPORT] Moving output Excel file back to root..."
    mv "${results_dir}/final_report_complete.xlsx" . || \
        (echo "No file generated in ${results_dir}!" && ls -R "${results_dir}" && exit 1)
    """
}