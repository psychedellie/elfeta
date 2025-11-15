process BWA_INDEX {
    tag "Bwa Index for $sample_id"
    label "bwa_indexing"
    conda "${params.envs_dir}/bwa-mem.yaml"
    
    publishDir "${params.output_dir}", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)

    output:
    tuple val(sample_id), path(assembly), path("samples/${sample_id}/bwa_index"), emit: index

    script:
    def out_dir = "samples/${sample_id}/bwa_index"

    """
    mkdir -p $out_dir

    bash ${params.scripts_dir}/bwa_index.sh \
        "${sample_id}" \
        "${assembly}" \
        "${out_dir}"
    """
}