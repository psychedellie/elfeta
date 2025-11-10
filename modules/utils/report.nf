process REPORT {
    tag "Generating run report"
    label 'report'
    conda "${params.envs_dir}/r-report.yaml"
    publishDir "${params.output_dir}", mode: 'copy'

    input:
        path results_dir        // This is params.output_dir (e.g., 'analysis/')
        path sample_sheet
        val completion_trigger  // This ensures we wait for pipeline completion
        val mode                // This is the 'params.mode' (e.g., "ont")

    output:
        path("final_report_complete.xlsx"), emit: rep

    script:
    // --- SOLUTION ---
    // The results are in a sub-directory. Define the REAL base directory.
    def report_base_dir = "${results_dir}/Results"
    """
    echo "[REPORT] Running R script: NGS_Report_v2.1.R"
    echo "[REPORT] Using results directory (base): ${results_dir}"
    echo "[REPORT] Using sample sheet: ${sample_sheet}"
    echo "[REPORT] Looking for tool results in: ${report_base_dir}"

    # Define the 7 arguments for the R script
    # Use the corrected 'report_base_dir' variable
    ARG1_RESULTS_DIR="${report_base_dir}"
    ARG2_SAMPLE_SHEET="${sample_sheet}"
    ARG3_QUAST_DIR="${report_base_dir}/QUAST"
    ARG4_MLST_DIR="${report_base_dir}/MLST"
    ARG5_RMLST_DIR="${report_base_dir}/rMLST"
    ARG6_PLASMID_DIR="${report_base_dir}/PlasmidFinder"
    ARG7_AMR_DIR="${report_base_dir}/AMRFinderPlus"

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
    # The R script will save the report relative to where it ran,
    # but the 'publishDir' will copy from the root.
    # The 'mv' in your original script was also likely wrong.
    # The R script should be configured to output to 'final_report_complete.xlsx'
    # in the process working directory.
    #
    # Assuming the R script *correctly* saves the file to ARG1_RESULTS_DIR:
    if [ -f "${report_base_dir}/final_report_complete.xlsx" ]; then
        mv "${report_base_dir}/final_report_complete.xlsx" .
    else
        echo "No file generated in ${report_base_dir}!" && ls -R "${report_base_dir}"
        # If the R script saves to the *working directory* instead, we just let publishDir work.
        # Let's check for that, just in case.
        if [ ! -f "final_report_complete.xlsx" ]; then
            echo "No report file found in EITHER location. R script may have failed." && exit 1
        fi
    fi
    """
}