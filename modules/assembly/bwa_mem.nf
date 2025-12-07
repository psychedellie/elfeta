process BWA_MEM {
    tag "$sample_id"
    label "bwa_mem_alignment"
    conda "${params.envs_dir}/bwa-mem.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/BWA_Mem", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/BWA_Mem", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}",                           mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), val(idx_prefix), path(r1), path(r2)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/${sample_id}_1.sam"), emit: sam1
        tuple val(sample_id), path("samples/${sample_id}/${sample_id}_2.sam"), emit: sam2
        path "versions.txt",                                                   emit: versions
        path ".command.*",                                                     emit: nf_logs

    script:
        """
        mkdir -p "samples/${sample_id}"

        bash ${params.scripts_dir}/bwa_mem.sh \
            "${sample_id}" \
            "${idx_prefix}" \
            "${r1}" \
            "${r2}" \
            "${task.cpus}" \
            ${args}
        """
}