process FLYE {
    tag "$sample_id"
    label 'flye_assembler'
    conda "${params.envs_dir}/flye.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/Flye", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}/logs/${sample_id}/Flye", mode: 'copy', pattern: "versions.txt"
    publishDir "${params.output_dir}",                        mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(fastq)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}"),                   emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/assembly.fasta"),    emit: fasta
        tuple val(sample_id), path("samples/${sample_id}/assembly_info.txt"), emit: txt
        path "versions.txt",                                                  emit: versions
        path ".command.*",                                                    emit: nf_logs

    script:
        def outdir = "samples/${sample_id}"

        """
        mkdir -p "${outdir}"

        bash ${params.scripts_dir}/flye.sh \
            "${fastq}" \
            "${outdir}" \
            "${task.cpus}" \
            ${args}
        """
}