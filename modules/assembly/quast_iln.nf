process QUAST {
    tag "$sample_id"
    label 'metrics'
    conda "${params.envs_dir}/quast.yaml"
    
    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(r1), path(r2), path(fasta)
        val(args)
    
    output:
        tuple val(sample_id), path("samples/${sample_id}/quast"),            emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/quast/report.tsv"), emit: tsv

    script:
        def outdir = "samples/${sample_id}/quast"
        
        """
        bash ${params.scripts_dir}/quast_iln.sh \
            "${fasta}" \
            "${outdir}" \
            "${r1}" \
            "${r2}" \
            "${task.cpus}" \
            ${args}
        """
}