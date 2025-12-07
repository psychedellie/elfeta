process UNICYCLER {
    tag "$sample_id"
    label 'unicycler_assembler'
    conda "${params.envs_dir}/unicycler.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/Unicycler", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/Unicycler", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}",                             mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(long_read), path(r1), path(r2)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}"),                emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/assembly.fasta"), emit: fasta
        path "versions.txt",                                               emit: versions
        path ".command.*",                                                 emit: nf_logs

    script:
        def outdir = "samples/${sample_id}"

        """
        mkdir -p "${outdir}"

        bash ${params.scripts_dir}/unicycler.sh \
            "${r1}" \
            "${r2}" \
            "${long_read}" \
            "${outdir}" \
            "${task.cpus}" \
            ${args}
        """
}