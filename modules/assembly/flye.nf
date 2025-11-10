process FLYE {
    tag "$sample_id"
    label 'flye_assembler'
    publishDir "${params.output_dir}", mode: 'copy'
    conda "${params.envs_dir}/flye.yaml"

    input:
        tuple val(sample_id), path(fastq)

    output:
        tuple val(sample_id), path("samples/${sample_id}/assembly.fasta"), emit: assembly
        tuple val(sample_id), path("samples/${sample_id}/assembly_info.txt"), emit: info

    script:
    """
    mkdir -p samples/${sample_id}
    bash ${params.scripts_dir}/flye.sh "${fastq}" "samples/${sample_id}" "${task.cpus}"
    """
}
