process RMLST {
    tag "$sample_id"
    label 'speciator'
    conda "${params.envs_dir}/rmlst.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/rMLST",         mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}",                                 mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(consensus)

    output:
        tuple val(sample_id), path("samples/${sample_id}/rmlst.tsv"),              emit: tsv
        tuple val(sample_id), path("samples/${sample_id}/${sample_id}.species"),   emit: species
        path ".command.*",                                                         emit: nf_logs

    script:
        def outdir = "samples/${sample_id}"
        def output = "${outdir}/rmlst.tsv"
        def species_file = "${outdir}/${sample_id}.species"
        def supported_organisms = "${params.scripts_dir}/config/supported_organisms.yaml"

        """
        bash ${params.scripts_dir}/run_rmlst.sh \
            "${consensus}" \
            "${output}" \
            "${supported_organisms}" \
            ${species_file} \
        """
}