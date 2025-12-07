process QUAST_ONT {
    tag "$sample_id"
    label 'quast_metrics'
    conda "${params.envs_dir}/quast.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/Quast_ONT", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/Quast_ONT", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}",                             mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(fastq), path(fasta)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/quast"),            emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/quast/report.tsv"), emit: tsv
        path "versions.txt",                                                 emit: versions
        path ".command.*",                                                   emit: nf_logs

    script:
        def outdir = "samples/${sample_id}/quast"

        """
        mkdir -p "${outdir}"

        bash ${params.scripts_dir}/quast_ont.sh \
            "${fasta}" \
            "${outdir}" \
            "${fastq}" \
            "${task.cpus}" \
            ${args}
        """
}