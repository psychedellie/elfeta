process MEDAKA {
    tag "$sample_id"
    label 'medaka_polishing'  
    conda params.enable_gpu ? "${params.envs_dir}/medaka_gpu.yaml" : "${params.envs_dir}/medaka_cpu.yaml"
    accelerator params.enable_gpu ? 1 : 0

    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(fastq), path(fasta)
        val(args)
    
    output:
        tuple val(sample_id), path("samples/${sample_id}/medaka/"),                emit: outdir
        tuple val(sample_id), path("samples/${sample_id}/medaka/consensus.fasta"), emit: fasta

    script:
        def outdir = "samples/${sample_id}/medaka"

        """
        bash ${params.scripts_dir}/medaka.sh \
            "${fastq}" \
            "${fasta}" \
            "${outdir}" \
            "${task.cpus}" \
            ${args}
        """
}