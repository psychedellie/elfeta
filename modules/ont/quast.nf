process QUAST {
    tag "QUAST on $sample_id"
    label 'metrics'
    
    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq), path(consensus)
    
    output:
    tuple val(sample_id), file("flye/${sample_id}/quast/report.tsv"), emit: metrics

    script:

    """
    bash ${projectDir}/scripts/quast.sh \
        "${consensus}" \
        "flye/${sample_id}/quast" \
        ${fastq} \
        "${task.cpus}"
    """
}