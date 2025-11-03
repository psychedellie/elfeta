process RESULTS_PUBLISHER {
    tag { "${tool} on ${sample_id}" }
    label 'results_publisher'

    publishDir "${params.outdir}/Results", mode: 'copy'

    input:
    tuple val(sample_id), path(result_file), val(tool)

    output:
    path "${tool}/${sample_id}_ONT.${result_file.extension}"

    script:
    """
    mkdir -p "${tool}"
    cp "${result_file}" "${tool}/${sample_id}_ONT.${result_file.extension}"
    """
}
