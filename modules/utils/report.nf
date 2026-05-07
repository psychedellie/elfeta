process REPORT {
    tag "Generating run report"
    label 'report'

    conda "${params.envs_dir}/r-report.yaml"

    publishDir "${params.output_dir}/Results", mode: 'copy'

    input:
        path results_dir
        path sample_sheet
        val completion_trigger
        val mode
        val assembly_dir_val

    output:
        path("final_report_complete.xlsx"), emit: xlsx
        path("final_report.html"), emit: html

    script:

        def report_base_dir = "${results_dir}/Results"

        def assembly_dir_path = ""
        if (mode == 'ont' || mode == 'sp') {
            assembly_dir_path = assembly_dir_val ?: ""
        }

        def fastp_dir_path = ""
        if (mode == 'ont' || mode == 'sp') {
            fastp_dir_path = "${results_dir}/fastplong"
        } else {
            fastp_dir_path = "${results_dir}/fastp"
        }

        def logs_dir_path = "${results_dir}/logs"

        def mob_dir_path  = "${report_base_dir}/MOBTyper"

        def virulence_dir_path = "${report_base_dir}/VirulenceFinder"

        """
        ARG1_RESULTS_DIR="${report_base_dir}"
        ARG2_SAMPLE_SHEET="${sample_sheet}"
        ARG3_QUAST_DIR="${report_base_dir}/QUAST"
        ARG4_MLST_DIR="${report_base_dir}/MLST"
        ARG5_RMLST_DIR="${report_base_dir}/rMLST"
        ARG6_PLASMID_DIR="${report_base_dir}/PlasmidFinder"
        ARG7_AMR_DIR="${report_base_dir}/AMRFinderPlus"
        ARG8_ASSEMBLY_DIR="${assembly_dir_path}"
        ARG9_PIPELINE_MODE="${mode}"
        ARG10_FASTP_DIR="${fastp_dir_path}"
        ARG11_LOGS_DIR="${logs_dir_path}"
        ARG12_MOB_DIR="${mob_dir_path}"
        ARG13_VIRULENCE_DIR="${virulence_dir_path}"

        Rscript "${params.scripts_dir}/NGS_Report_v2.1.R" \
            "\$ARG1_RESULTS_DIR" \
            "\$ARG2_SAMPLE_SHEET" \
            "\$ARG3_QUAST_DIR" \
            "\$ARG4_MLST_DIR" \
            "\$ARG5_RMLST_DIR" \
            "\$ARG6_PLASMID_DIR" \
            "\$ARG7_AMR_DIR" \
            "\$ARG8_ASSEMBLY_DIR" \
            "\$ARG9_PIPELINE_MODE" \
            "\$ARG10_FASTP_DIR" \
            "\$ARG11_LOGS_DIR" \
            "\$ARG12_MOB_DIR" \
            "\$ARG13_VIRULENCE_DIR"

        mv "${report_base_dir}/final_report_complete.xlsx" .
        mv "${report_base_dir}/final_report.html" .
        """
}