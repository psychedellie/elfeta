process POLYPOLISH_FILTER {
    tag "$sample_id"
    label "polypolish_filter"
    conda "${params.envs_dir}/polypolish.yaml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(sam1), path(sam2)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/polypolish/${sample_id}.filtered_1.sam"), path("samples/${sample_id}/polypolish/${sample_id}.filtered_2.sam"), emit: sams

    script:
        """
        bash ${params.scripts_dir}/polypolish_filter.sh \
            "${sam1}" \
            "${sam2}" \
            "${sample_id}" \
            ${args}
        """
    }