process SHOVILL {
    tag "$sample_id"
    label 'shovill_assembler'
    conda "${params.envs_dir}/shovill.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/Shovill", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/Shovill", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}",                           mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(r1), path(r2)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}"),             emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/contigs.fa"),  emit: fasta
        path "versions.txt",                                            emit: versions
        path ".command.*",                                              emit: nf_logs

    script:
        def outdir = "samples/${sample_id}"

        """
        mkdir -p "${outdir}"

        bash ${params.scripts_dir}/shovill.sh \
            "${r1}" \
            "${r2}" \
            "${outdir}" \
            "${task.cpus}" \
            "${task.memory.toMega()}" \
            "${args}"
        """
}