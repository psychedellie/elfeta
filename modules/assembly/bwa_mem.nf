process BWA_MEM {
    tag "Bwa Mem and Samtools for $sample_id"
    label "bwa_mem_samtools"
    conda "${params.envs_dir}/bwa-mem.yaml"
    
    publishDir "${params.output_dir}", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly), path(index_dir), path(r1), path(r2)

    output:
    tuple val(sample_id), path("samples/${sample_id}/${sample_id}.sorted.bam"),     emit: bam
    tuple val(sample_id), path("samples/${sample_id}/${sample_id}.sorted.bam.bai"), emit: bai

    script:
    def out_dir = "samples/${sample_id}"

    """
    mkdir -p $out_dir

    bash ${params.scripts_dir}/bwa_mem.sh \
        "${sample_id}" \
        "${index_dir}" \
        "${r1}" \
        "${r2}" \
        "${task.cpus}" \
        "${out_dir}"
    """
}