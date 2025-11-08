process SHOVILL {
    tag { sample_id }
    label 'shovill_assembler'
    publishDir "${params.outdir}/Shovill", mode: 'copy'
    conda "${params.envs_dir}/shovill.yaml"

    input:
        tuple val(sample_id), path(fastq1), path(fastq2)

    output:
        tuple val(sample_id), path("shovill/${sample_id}/contigs.fa"), emit: assembly

    script:
    """
    mkdir -p shovill/${sample_id}
    echo "[SHOVILL] Starting assembly for ${sample_id}"
    echo "[SHOVILL] CPUs: ${task.cpus}"
    echo "[SHOVILL] Memory: ${task.memory.toMega()} MB"

    bash ${params.scripts_dir}/shovill.sh \
        "${fastq1}" \
        "${fastq2}" \
        "shovill/${sample_id}" \
        "${task.cpus}" \
        "${task.memory.toMega()}"
    """
}
