process BWA_INDEX {
    tag "$sample_id"
    label "bwa_indexing"
    conda "${params.envs_dir}/bwa-mem.yaml"
    
    publishDir "${params.output_dir}/logs/${sample_id}/BWA_Index", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/BWA_Index", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}",                             mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(fasta)
        val(args)

    output:
        tuple val(sample_id), path(fasta), path("samples/${sample_id}/bwa_index"), emit: idx
        path "versions.txt",                                                       emit: versions
        path ".command.*",                                                         emit: nf_logs

    script:
        def out_dir = "samples/${sample_id}/bwa_index"

        """
        mkdir -p "${out_dir}"

        bash ${params.scripts_dir}/bwa_index.sh \
            "${sample_id}" \
            "${fasta}" \
            "${out_dir}" \
            ${args}
        """
}