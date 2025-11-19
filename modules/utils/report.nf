process REPORT {
    tag "Generating run report"
    label 'report'
    conda "${params.envs_dir}/r-report.yaml"
    
    publishDir "${params.output_dir}", mode: 'copy'

    input:
        path results_dir
        path sample_sheet
        val completion_trigger
        val mode

    output:
        path("final_report_complete.xlsx"), emit: xlsx

    script:
        def report_base_dir = "${results_dir}/Results"

        """
        ARG1_RESULTS_DIR="${report_base_dir}"
        ARG2_SAMPLE_SHEET="${sample_sheet}"
        ARG3_QUAST_DIR="${report_base_dir}/QUAST"
        ARG4_MLST_DIR="${report_base_dir}/MLST"
        ARG5_RMLST_DIR="${report_base_dir}/rMLST"
        ARG6_PLASMID_DIR="${report_base_dir}/PlasmidFinder"
        ARG7_AMR_DIR="${report_base_dir}/AMRFinderPlus"

        Rscript "${params.scripts_dir}/NGS_Report_v2.1.R" \
            "\$ARG1_RESULTS_DIR" \
            "\$ARG2_SAMPLE_SHEET" \
            "\$ARG3_QUAST_DIR" \
            "\$ARG4_MLST_DIR" \
            "\$ARG5_RMLST_DIR" \
            "\$ARG6_PLASMID_DIR" \
            "\$ARG7_AMR_DIR"

        mv "${report_base_dir}/final_report_complete.xlsx" .
        """
}