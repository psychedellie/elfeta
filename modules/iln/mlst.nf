process MLST {
    tag "MLST on $sample_id"
    label 'mlst_typing'
    conda "${params.envs_dir}/mlst.yaml"
    
    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(sample_id), path(consensus)
    
    output:
    tuple val(sample_id), path("shovill/${sample_id}/mlst.tsv"), emit: mlst

    script:
    def out_dir = "shovill/${sample_id}"
    def out_file = "${out_dir}/mlst.tsv"
    
    """
    mkdir -p $out_dir

    bash ${params.scripts_dir}/mlst.sh \
        "${consensus}" \
        "${sample_id}" \
        "${out_file}"
    """
}