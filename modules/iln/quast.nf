process QUAST {
    tag "QUAST on $sample_id"
    label 'metrics'
    conda "${params.envs_dir}/quast.yaml"
    
    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(sample_id), path(r1), path(r2), path(consensus)  // Separate R1 and R2
    
    output:
    tuple val(sample_id), file("shovill/${sample_id}/quast/report.tsv"), emit: metrics

    script:
    def out_dir = "shovill/${sample_id}/quast"
    """
    mkdir -p $out_dir

    bash ${params.scripts_dir}/quast_iln.sh \
        "${consensus}" \
        "${out_dir}" \
        "${r1}" \
        "${r2}" \
        "${task.cpus}"
    """
}