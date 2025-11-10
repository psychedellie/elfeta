process MERGE_FASTQS {
    tag "${sample_sheet.simpleName}"
    publishDir "${params.output_dir}", mode: 'copy'

    input:
        path input_dir
        path sample_sheet

    output:
        path "fastqs_merged/*.fastq.gz", emit: out

    script:
    
    """
    mkdir -p reads_merged
    bash ${params.scripts_dir}/merge_fastqs.sh "${input_dir}" "fastqs_merged" "${sample_sheet}"
    """
}