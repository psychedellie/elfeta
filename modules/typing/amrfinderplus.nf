process AMRFINDERPLUS {
    tag "$sample_id"
    label 'amrfinder'
    publishDir "${params.output_dir}", mode: 'copy'
    conda "${params.envs_dir}/amrfinderplus.yaml"

    input:
        tuple val(sample_id), path(consensus), path(species_file)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/${sample_id}_amrf.txt"), emit: txt

    script:
        def db = "${params.db_root}/amrfinder-db/latest"
        def output = "samples/${sample_id}/${sample_id}_amrf.txt"

        """
        SPECIES_NAME=\$(cat "${species_file}")

        bash ${params.scripts_dir}/amrfinderplus.sh \
            "${consensus}" \
            "${output}" \
            "${task.cpus}" \
            "\$SPECIES_NAME" \
            "${db}" \
            ${args}
        """
}