process FLYE {
    tag { sample_id }
    label 'flye_assembler'
    publishDir "${params.outdir}", mode: 'copy'

    input:
        tuple val(sample_id), path(fastq)

    output:
        tuple val(sample_id), path("flye/${sample_id}/assembly.fasta"), emit: assembly
        tuple val(sample_id), path("flye/${sample_id}/assembly_info.txt"), emit: info

    script:
    """
    mkdir -p flye/${sample_id}
    bash ${projectDir}/scripts/flye.sh "${fastq}" "flye/${sample_id}" "${task.cpus}"
    """
}
