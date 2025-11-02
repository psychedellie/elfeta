process FASTPLONG {
    label 'fastplong'
    publishDir "${params.outdir}", mode: 'copy'

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
        bash ${projectDir}/scripts/fastplong.sh \
            ${input_dir} \
            "fastplong" \
            ${task.cpus}
        """
}