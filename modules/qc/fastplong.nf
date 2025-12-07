process FASTPLONG {
    tag "$input_dir"
    label 'fastplong'
    conda "${params.envs_dir}/fastplong.yaml"

    publishDir "${params.output_dir}/logs/fastplong", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/fastplong", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}",                mode: 'copy', pattern: "fastplong/**"

    input:
        path(input_dir)
        val(args)

    output:
        path("fastplong/filtered_reads/*.hq.fastq.gz"), emit: filtered
        path("fastplong/*.html"),                       emit: html
        path("fastplong/*.json"),                       emit: json  
        path("fastplong/*.log"),                        emit: logs
        path "versions.txt",                            emit: versions
        path ".command.*",                              emit: nf_logs

    script:
        def outdir = "fastplong"

        """
        mkdir -p "${outdir}"

        bash ${params.scripts_dir}/fastplong.sh \
            "${input_dir}" \
            "${outdir}" \
            "${task.cpus}" \
            ${args}
        """
}