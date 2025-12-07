process BAKTA {
    tag "$sample_id"
    label 'bakta_annotation'
    conda "${params.envs_dir}/bakta.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/Bakta", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/Bakta", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}/logs/${sample_id}/Bakta", mode: 'copy', pattern: "db_version.txt"
    publishDir "${params.output_dir}",                         mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(fasta)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/bakta"),                     emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/bakta/${sample_id}.tsv"),    emit: tsv
        tuple val(sample_id), path("samples/${sample_id}/bakta/${sample_id}.faa"),    emit: faa
        tuple val(sample_id), path("samples/${sample_id}/bakta/${sample_id}.gbff"),   emit: gbff
        path "versions.txt",                                                          emit: versions
        path "db_version.txt",                                                        emit: db_version
        path ".command.*",                                                            emit: nf_logs

    script:
        def outdir = "samples/${sample_id}/bakta"
        def db = "${params.db_root}/bakta"

        """
        mkdir -p "${outdir}"

        bash ${params.scripts_dir}/bakta.sh \
            "${fasta}" \
            "${outdir}" \
            "${sample_id}" \
            "${task.cpus}" \
            "${db}" \
            ${args}
        """
}