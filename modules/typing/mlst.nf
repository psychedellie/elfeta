process MLST {
    tag "$sample_id"
    label 'mlst_typing'
    conda "${params.envs_dir}/mlst.yaml"
    
    publishDir "${params.output_dir}/logs/${sample_id}/MLST", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/MLST", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}",                        mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(fasta)
        val(args)
    
    output:
        tuple val(sample_id), path("samples/${sample_id}/mlst.tsv"), emit: tsv
        path "versions.txt",                                         emit: versions
        path ".command.*",                                           emit: nf_logs

    script:
        def outdir = "samples/${sample_id}"
        def out_file = "${outdir}/mlst.tsv"
        
        """
        mkdir -p "${outdir}"

        bash ${params.scripts_dir}/mlst.sh \
            "${fasta}" \
            "${sample_id}" \
            "${out_file}" \
            ${args}
        """
}