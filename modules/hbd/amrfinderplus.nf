process AMRFINDERPLUS {
    tag "AMRFinderPlus on $sample_id"
    label 'amrfinder'
    conda "${params.envs_dir}/amrfinderplus.yaml"
    
    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(sample_id), path(consensus), path(species_file)
    
    output:
    tuple val(sample_id), path("flye/${sample_id}/${sample_id}_ONT_amrf.txt"), emit: amrf

    script:
    def out_dir  = "flye/${sample_id}"
    def out_file = "${out_dir}/${sample_id}_ONT_amrf.txt"

    """
    mkdir -p "${out_dir}"

    # Read species name from file into a bash variable
    SPECIES_NAME=\$(cat "${species_file}")

    bash ${params.scripts_dir}/amrfinderplus.sh \
        "${consensus}" \
        "${out_file}" \
        "\$SPECIES_NAME" \
        "${task.cpus}"
    """
}
