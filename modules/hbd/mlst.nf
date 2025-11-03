process MLST {
    tag "MLST on $sample_id"
    label 'mlst_typing'
    conda "${params.envs_dir}/mlst.yaml"
    
    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(sample_id), path(consensus)
    
    output:
    tuple val(sample_id), path("flye/${sample_id}/mlst.tsv"), emit: mlst

    script:
    def out_file = "flye/${sample_id}/mlst.tsv"

    """
    bash ${params.scripts_dir}/mlst.sh \
        "${consensus}" \
        "${sample_id}" \
        "${out_file}"
    """
}