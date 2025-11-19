process PLASMIDFINDER {
    tag "$sample_id"
    label 'plasmidfinder'
    conda "${params.envs_dir}/plasmidfinder.yaml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(fasta), path(db_root)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/plasmidfinder"),                 emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/plasmidfinder/results_tab.tsv"), emit: tsv

    script:
        def db = "${params.db_root}/plasmidfinder"
        def outdir = "samples/${sample_id}/plasmidfinder"

        """
        bash ${params.scripts_dir}/plasmidfinder.sh \
            "${fasta}" \
            "${outdir}" \
            "${db}" \
            "${args}"
        """
}