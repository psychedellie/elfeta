process MERGE_FASTQS {
    tag "${sample_sheet.simpleName}"
    publishDir "${params.outdir}", mode: 'copy'

    input:
        path input_dir
        path sample_sheet

    output:
        path "reads_merged/*.fastq.gz", emit: out

    script:
    """
    mkdir -p reads_merged
    bash ${params.scripts_dir}/merge_fastqs.sh "${input_dir}" "reads_merged" "${sample_sheet}"
    """
}