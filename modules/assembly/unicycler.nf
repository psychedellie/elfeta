process SHOVILL {
    tag "$sample_id"
    label 'shovill_assembler'
    publishDir "${params.output_dir}", mode: 'copy'
    conda "${params.envs_dir}/shovill.yaml"

    input:
        tuple val(sample_id), path(fastq1), path(fastq2)

    output:
        tuple val(sample_id), path("samples/${sample_id}/contigs.fa"), emit: assembly

    script:
    """
    mkdir -p samples/${sample_id}
    echo "[Shovill] Starting assembly for ${sample_id}"
    echo "[Shovill] CPUs: ${task.cpus}"
    echo "[Shovill] Memory: ${task.memory.toMega()} MB"

    bash ${params.scripts_dir}/shovill.sh \
        "${fastq1}" \
        "${fastq2}" \
        "samples/${sample_id}" \
        "${task.cpus}" \
        "${task.memory.toMega()}"
    """
}
