process BWA_INDEX {
    tag "$sample_id"
    label "bwa_indexing"
    conda "${params.envs_dir}/bwa-mem.yaml"
    
    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(fasta)

    output:
        tuple val(sample_id), path(fasta), path("samples/${sample_id}/bwa_index"), emit: idx

    script:
        def out_dir = "samples/${sample_id}/bwa_index"

        """
        bash ${params.scripts_dir}/bwa_index.sh \
            "${sample_id}" \
            "${fasta}" \
            "${out_dir}"
        """
}