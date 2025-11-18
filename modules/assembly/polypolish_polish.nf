process POLYPOLISH_POLISH {
    tag "Polypolish polish for $sample_id"
    label "polypolish_polish"
    conda "${params.envs_dir}/polypolish.yaml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly), path(filtered_sam1), path(filtered_sam2), val(args)

    output:
    tuple val(sample_id), path("samples/${sample_id}/consensus.fasta"), emit: assembly 

    script:
    """
    # This now matches your fixed polypolish.sh script
    bash ${params.scripts_dir}/polypolish_polish.sh \
        "${sample_id}" \
        "${assembly}" \
        "${filtered_sam1}" \
        "${filtered_sam2}" \
        "${args}"  
    """
}