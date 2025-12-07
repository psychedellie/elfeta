process AMRFINDERPLUS {
    tag "$sample_id"
    label 'amrfinder'
    conda "${params.envs_dir}/amrfinderplus.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/AMRFinderPlus", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/AMRFinderPlus", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}/logs/${sample_id}/AMRFinderPlus", mode: 'copy', pattern: "db_version.txt"
    publishDir "${params.output_dir}",                                 mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(consensus), path(species_file)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/${sample_id}_amrf.txt"), emit: txt
        path "versions.txt",                                                      emit: versions
        path "db_version.txt",                                                    emit: db_version
        path ".command.*",                                                        emit: nf_logs

    script:
        def db = "${params.db_root}/amrfinder-db/latest"
        def output_file = "samples/${sample_id}/${sample_id}_amrf.txt"

        """
        mkdir -p "samples/${sample_id}"
        SPECIES_NAME=\$(cat "${species_file}")

        bash ${params.scripts_dir}/amrfinderplus.sh \
            "${consensus}" \
            "${output_file}" \
            "${task.cpus}" \
            "\$SPECIES_NAME" \
            "${db}" \
            ${args}
        """
}