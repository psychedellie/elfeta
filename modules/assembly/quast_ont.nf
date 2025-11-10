process QUAST {
    tag "QUAST on $sample_id"
    label 'metrics'
    conda "${params.envs_dir}/quast.yaml"
    
    publishDir "${params.output_dir}", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq), path(consensus)
    
    output:
    tuple val(sample_id), file("samples/${sample_id}/quast/report.tsv"), emit: metrics

    script:
    def out_dir = "samples/${sample_id}/quast"
    """
    mkdir -p $out_dir

        bash ${params.scripts_dir}/quast_ont.sh \
            "${consensus}" \
            "${out_dir}" \
            "${fastq}" \
            "${task.cpus}"
    """
}