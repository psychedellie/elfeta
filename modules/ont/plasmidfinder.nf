process PLASMIDFINDER {
    tag "Plasmidfinder on $sample_id"
    label 'plasmid_id'
    
    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(sample_id), path(consensus), path(db_root)
    
    output:
    tuple val(sample_id), path("flye/${sample_id}/plasmidfinder"), emit: plasmid
    tuple val(sample_id), path("flye/${sample_id}/plasmidfinder/results.txt"), emit: txt

    script:
    """
    mkdir -p "flye/${sample_id}/plasmidfinder"
    
    bash ${projectDir}/scripts/plasmidfinder.sh \
        "${consensus}" \
        "flye/${sample_id}/plasmidfinder" \
        "${db_root}/plasmidfinder" 
    """
}