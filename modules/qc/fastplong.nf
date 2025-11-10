process FASTPLONG {
    label 'fastplong'
    publishDir "${params.output_dir}", mode: 'copy'
    conda "${params.envs_dir}/fastplong.yaml"

    input:
    path(input_dir)

    output:
    path("fastplong/filtered_reads/*.hq.fastq.gz"), emit: filtered
    path("fastplong/*.html"), emit: html_reports
    path("fastplong/*.json"), emit: json_reports  
    path("fastplong/*.log"), emit: log_files

    script:
        """
        # Run fastplong - it expects an input directory, not a single file
        bash ${params.scripts_dir}/fastplong.sh \
            ${input_dir} \
            "fastplong" \
            ${task.cpus}
        """
}