process SHOVILL {
    tag "$sample_id"
    label 'shovill_assembler'
    conda "${params.envs_dir}/shovill.yaml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(r1), path(r2)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}"),            emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/contigs.fa"), emit: fasta

    script:
    def outdir = "samples/${sample_id}"

    """
    bash ${params.scripts_dir}/shovill.sh \
        "${r1}" \
        "${r2}" \
        "${outdir}" \
        "${task.cpus}" \
        "${task.memory.toMega()}" \
        "${args}"
    """
}