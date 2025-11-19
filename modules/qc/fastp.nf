process FASTP {
    tag "$input_dir"
    label 'fastp'
    conda "${params.envs_dir}/fastp.yaml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
        path(input_dir)
        val(args)

    output:
        path("fastp/filtered_reads/*.hq.fastq.gz"), emit: filtered 
        path("fastp/*.html"),                       emit: html_reports
        path("fastp/*.json"),                       emit: json_reports  
        path("fastp/*.log"),                        emit: log_files

    script:
        def outdir = "fastp"

        """
        bash ${params.scripts_dir}/fastp.sh \
            "${input_dir}" \
            "${outdir}" \
            "${task.cpus}" \
            "${args}"
        """
}