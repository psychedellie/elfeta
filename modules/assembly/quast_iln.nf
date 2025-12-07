process QUAST_ILN {
    tag "$sample_id"
    label 'metrics'
    conda "${params.envs_dir}/quast.yaml"
    
    publishDir "${params.output_dir}/logs/${sample_id}/Quast_ILN", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/Quast_ILN", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}",                             mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(r1), path(r2), path(fasta)
        val(args)
    
    output:
        tuple val(sample_id), path("samples/${sample_id}/quast"),            emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/quast/report.tsv"), emit: tsv
        path "versions.txt",                                                 emit: versions
        path ".command.*",                                                   emit: nf_logs

    script:
        def outdir = "samples/${sample_id}/quast"
        
        """
        mkdir -p "${outdir}"

        bash ${params.scripts_dir}/quast_iln.sh \
            "${fasta}" \
            "${outdir}" \
            "${r1}" \
            "${r2}" \
            "${task.cpus}" \
            ${args}
        """
}