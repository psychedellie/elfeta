process POLYPOLISH {
    tag "Polypolish for $sample_id"
    label "polypolish"
    conda "${params.envs_dir}/polypolish.yaml"
    
    publishDir "${params.output_dir}"

    input:
    tuple val(sample_id), path(assembly), path(bam), path(bai), val(args)

    output:
    tuple val(sample_id), path("samples/${sample_id}/${sample_id}.fasta"), emit: assembly 

    script:
    """
    bash ${params.scripts_dir}/polypolish.sh \
        "${sample_id}" \
        "${assembly}" \
        "${bam}" \
        "${args}"  
    """
}