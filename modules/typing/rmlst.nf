process RMLST {
    tag "rMLST on $sample_id"
    label 'speciator'
    conda "${params.envs_dir}/rmlst.yaml"
    
    publishDir "${params.output_dir}", mode: 'copy'

    input:
    tuple val(sample_id), path(consensus)
    
    output:
    tuple val(sample_id), file("samples/${sample_id}/${sample_id}_rmlst.tsv"), emit: tsv
    tuple val(sample_id), file("samples/${sample_id}/${sample_id}.species"), emit: species

    script:
    def organism_file = "${params.scripts_dir}/config/supported_organisms.yaml"
    def out_dir = "samples/${sample_id}"
    """
    mkdir -p $out_dir

    bash ${params.scripts_dir}/run_rmlst.sh \
        "${consensus}" \
        "${out_dir}/${sample_id}_rmlst.tsv" \
        ${organism_file} \
        "${out_dir}/${sample_id}.species"
    """
}