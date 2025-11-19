process QUAST {
    tag "$sample_id"
    label 'quast_metrics'
    conda "${params.envs_dir}/quast.yaml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(fastq), path(fasta)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/quast"),            emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/quast/report.tsv"), emit: tsv

    script:
        def outdir = "samples/${sample_id}/quast"

        """
        bash ${params.scripts_dir}/quast_ont.sh \
            "${fasta}" \
            "${outdir}" \
            "${fastq}" \
            "${task.cpus}" \
            "${args}"
        """
}