process RMLST {
    tag "rMLST on $sample_id"
    label 'speciator'
    conda "${params.envs_dir}/rmlst.yaml"
    
    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(sample_id), path(consensus)
    
    output:
    tuple val(sample_id), file("flye/${sample_id}/${sample_id}_rmlst.tsv"), emit: tsv
    tuple val(sample_id), file("flye/${sample_id}/${sample_id}.species"), emit: species

    script:
    def organism_file = "${params.scripts_dir}/config/supported_organisms.yaml"

    """
    bash ${params.scripts_dir}/run_rmlst.sh \
        "${consensus}" \
        "flye/${sample_id}/${sample_id}_rmlst.tsv" \
        ${organism_file} \
        "flye/${sample_id}/${sample_id}.species"
    """
}