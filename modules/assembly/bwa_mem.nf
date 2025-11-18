process BWA_MEM {
    tag "Bwa Mem and Samtools for $sample_id"
    label "bwa_mem_samtools"
    conda "${params.envs_dir}/bwa-mem.yaml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
    tuple val(sample_id), val(index_prefix), path(r1), path(r2)

    output:
    tuple val(sample_id), path("samples/${sample_id}/${sample_id}_1.sam"), emit: sam1
    tuple val(sample_id), path("samples/${sample_id}/${sample_id}_2.sam"), emit: sam2

    script:

    """

    bash ${params.scripts_dir}/bwa_mem.sh \
        ${sample_id} \
        "${index_prefix}" \
        ${r1} \
        ${r2} \
        ${task.cpus}
    """
}