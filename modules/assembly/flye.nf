process FLYE {
    tag "$sample_id"
    label 'flye_assembler'
    conda "${params.envs_dir}/flye.yaml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(fastq)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}"),                   emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/assembly.fasta"),    emit: fasta
        tuple val(sample_id), path("samples/${sample_id}/assembly_info.txt"), emit: txt

    script:
        def outdir = "samples/${sample_id}"

        """
        bash ${params.scripts_dir}/flye.sh \
            "${fastq}" \
            "${outdir}" \
            "${task.cpus}" \
            "${args}"
        """
}