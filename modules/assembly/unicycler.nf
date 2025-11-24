process UNICYCLER {
    tag "$sample_id"
    label 'unicycler_assembler'
    conda "${params.envs_dir}/unicycler.yaml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(long_read), path(r1), path(r2)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}"),                emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/assembly.fasta"), emit: fasta

    script:
    def outdir = "samples/${sample_id}"

    """
    bash ${params.scripts_dir}/unicycler.sh \
        "${r1}" \
        "${r2}" \
        "${long_read}" \
        "${outdir}" \
        "${task.cpus}" \
        ${args}
    """
}