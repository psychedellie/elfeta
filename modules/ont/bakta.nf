process BAKTA {
    tag "Bakta on $sample_id"
    label 'bakta_annotation'
    conda "${params.envs_dir}/bakta.yaml"
    
    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)
    
    output:
    tuple val(sample_id), path("flye/${sample_id}/bakta"), emit: annot
    tuple val(sample_id), path("flye/${sample_id}/bakta/${sample_id}.tsv"), emit: tsv
    tuple val(sample_id), path("flye/${sample_id}/bakta/${sample_id}.faa"), emit: faa

    script:
    def out_dir = "flye/${sample_id}/bakta"

    """
    mkdir -p "out_dir"
    
    bash ${params.scripts_dir}/bakta.sh \
        "${assembly}" \
        "${out_dir}" \
        "${sample_id}" \
        "${task.cpus}" \
        "${params.db_root}/bakta"
    """
}