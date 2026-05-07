process VIRULENCEFINDER {
    tag "$sample_id"
    label 'virulencefinder'
    conda "${params.envs_dir}/virulencefinder.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/VirulenceFinder", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/VirulenceFinder", mode: 'copy', pattern: "db_version.txt"
    publishDir "${params.output_dir}", mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(fasta), path(rmlst_tsv), path(db_root)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/virulencefinder"), emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/virulencefinder/results_tab.tsv"), emit: tsv
        tuple val(sample_id), path("samples/${sample_id}/virulencefinder/virulencefinder_status.tsv"), emit: status
        path "db_version.txt", emit: db_version
        path ".command.*", emit: nf_logs

    script:
        def db = "${params.db_root}/virulencefinder"
        def outdir = "samples/${sample_id}/virulencefinder"

        """
        mkdir -p "${outdir}"

        bash ${params.scripts_dir}/virulencefinder.sh \
            "${sample_id}" \
            "${fasta}" \
            "${rmlst_tsv}" \
            "${outdir}" \
            "${db}" \
            ${args}
        """
}