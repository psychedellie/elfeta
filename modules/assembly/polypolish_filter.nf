process POLYPOLISH_FILTER {
    tag "$sample_id"
    label "polypolish_filter"
    conda "${params.envs_dir}/polypolish.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/Polypolish_Filter", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/Polypolish_Filter", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}",                                     mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(sam1), path(sam2)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/polypolish/${sample_id}.filtered_1.sam"), path("samples/${sample_id}/polypolish/${sample_id}.filtered_2.sam"), emit: sams
        path "versions.txt",                                                                                                                                           emit: versions
        path ".command.*",                                                                                                                                             emit: nf_logs

    script:
        """
        mkdir -p "samples/${sample_id}/polypolish"

        bash ${params.scripts_dir}/polypolish_filter.sh \
            "${sam1}" \
            "${sam2}" \
            "${sample_id}" \
            ${args}
        """
}