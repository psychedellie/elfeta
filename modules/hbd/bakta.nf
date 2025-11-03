process BAKTA {
    tag "Bakta on $sample_id"
    label 'bakta_annotation'
    conda "${params.envs_dir}/bakta.yaml"
    
    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(sample_id), path(consensus), path(db_root)
    
    output:
    tuple val(sample_id), path("flye/${sample_id}/bakta"), emit: annot
    tuple val(sample_id), path("flye/${sample_id}/bakta/${sample_id}.tsv"), emit: tsv
    tuple val(sample_id), path("flye/${sample_id}/bakta/${sample_id}.faa"), emit: faa

    script:
    """
    mkdir -p "flye/${sample_id}/bakta"
    
    bash ${params.scripts_dir}/bakta.sh \
        "${consensus}" \
        "flye/${sample_id}/bakta" \
        "${sample_id}" \
        "${task.cpus}" \
        "${db_root}/bakta"
    """
}