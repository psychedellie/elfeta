process MLST {
    tag "MLST on $sample_id"
    label 'mlst_typing'
    conda "${params.envs_dir}/mlst.yaml"
    
    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(fasta)
        val(args)
    
    output:
        tuple val(sample_id), path("samples/${sample_id}/mlst.tsv"), emit: tsv

    script:
        def outdir = "samples/${sample_id}"
        def out_file = "${outdir}/mlst.tsv"
        
        """
        bash ${params.scripts_dir}/mlst.sh \
            "${fasta}" \
            "${sample_id}" \
            "${out_file}" \
            "${args}"
        """
}