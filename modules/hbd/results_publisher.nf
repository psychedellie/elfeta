process RESULTS_PUBLISHER {
    tag "$tool on $sample_id"
    label 'results_publisher'

    publishDir "${params.outdir}/Results", mode: 'copy'
    input:
        tuple val(sample_id), path(result_file), val(tool), val(mode)

    output:
        path "${tool}/${sample_id}_${mode.toUpperCase()}.${result_file.extension}", emit: published_file

    script:
    
    """
    MODE_UPPER=\$(echo "${mode}" | tr '[:lower:]' '[:upper:]')
    mkdir -p "${tool}"
    cp "${result_file}" "${tool}/${sample_id}_\${MODE_UPPER}.${result_file.extension}"
    """
}