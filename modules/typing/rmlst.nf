process RMLST {
    tag "$sample_id"
    label 'speciator'
    conda "${params.envs_dir}/rmlst.yaml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(consensus)

    output:
        tuple val(sample_id), path("samples/${sample_id}/${sample_id}_rmlst.tsv"), emit: tsv
        tuple val(sample_id), path("samples/${sample_id}/${sample_id}.species"),   emit: species

    script:
        def outdir = "samples/${sample_id}"
        def output = "${outdir}/${sample_id}_rmlst.tsv"
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