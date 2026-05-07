process PLASMIDFINDER {
    tag "$sample_id"
    label 'plasmidfinder'
    conda "${params.envs_dir}/plasmidfinder.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/PlasmidFinder", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/PlasmidFinder", mode: 'copy', pattern: "db_version.txt"
    publishDir "${params.output_dir}",                                 mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(fasta), path(db_root)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/plasmidfinder"),                 emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/plasmidfinder/results_tab.tsv"), emit: tsv
        path "db_version.txt",                                                            emit: db_version
        path ".command.*",                                                                emit: nf_logs

    script:
        def db = "${params.db_root}/plasmidfinder"
        def outdir = "samples/${sample_id}/plasmidfinder"

        """
        mkdir -p "${outdir}"

        bash ${params.scripts_dir}/plasmidfinder.sh \
            "${fasta}" \
            "${outdir}" \
            "${db}" \
            ${args}
        """
}