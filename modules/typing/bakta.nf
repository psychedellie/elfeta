process BAKTA {
    tag "$sample_id"
    label 'bakta_annotation'
    conda "${params.envs_dir}/bakta.yaml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(fasta)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/bakta"),                     emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/bakta/${sample_id}.tsv"),    emit: tsv
        tuple val(sample_id), path("samples/${sample_id}/bakta/${sample_id}.faa"),    emit: faa
        tuple val(sample_id), path("samples/${sample_id}/bakta/${sample_id}.gbff"),   emit: gbff

    script:
        def outdir = "samples/${sample_id}/bakta"
        def db = "${params.db_root}/bakta"

        """
        bash ${params.scripts_dir}/bakta.sh \
            "${fasta}" \
            "${outdir}" \
            "${sample_id}" \
            "${task.cpus}" \
            "${db}" \
            ${args}
        """
}