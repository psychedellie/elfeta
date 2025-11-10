process FASTP {
    label 'fastp'
    publishDir "${params.output_dir}", mode: 'copy'
    conda "${params.envs_dir}/fastp.yaml"

    input:
    path(input_dir)

    output:
    path("fastp/filtered_reads/*.hq.fastq.gz"), emit: filtered 
    path("fastp/*.html"), emit: html_reports
    path("fastp/*.json"), emit: json_reports  
    path("fastp/*.log"), emit: log_files

    script:
        """
        # Run fastp - it expects an input directory, not a single file
        bash ${params.scripts_dir}/fastp.sh \
            ${input_dir} \
            "fastp" \
            ${task.cpus}
        """
}