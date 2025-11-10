process PLASMIDFINDER {
    tag "Plasmidfinder on $sample_id"
    label 'plasmid_id'
    conda "${params.envs_dir}/gep-finders.yaml"
    
    publishDir "${params.output_dir}", mode: 'copy'

    input:
    tuple val(sample_id), path(consensus), path(db_root)
    
    output:
    tuple val(sample_id), path("samples/${sample_id}/plasmidfinder"), emit: plasmid
    tuple val(sample_id), path("samples/${sample_id}/plasmidfinder/results.txt"), emit: txt

    script:
    def out_dir = "samples/${sample_id}/plasmidfinder"

    """
    mkdir -p "${out_dir}"
    
    bash ${params.scripts_dir}/plasmidfinder.sh \
        "${consensus}" \
        "${out_dir}" \
        "${params.db_root}/plasmidfinder" 
    """
}