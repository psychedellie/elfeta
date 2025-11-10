process MEDAKA {
    tag "$sample_id"
    label 'medaka_polishing'
    publishDir "${params.output_dir}", mode: 'copy'
    
    // Dynamic environment selection based on GPU availability
    conda params.enable_gpu ? "${params.envs_dir}/medaka_gpu.yaml" : "${params.envs_dir}/medaka_cpu.yaml"

    // Use GPU if available, otherwise skip silently
    accelerator params.enable_gpu ? 1 : 0

    input:
    tuple val(sample_id), path(fastq), path(assembly), val(basecaller)

    output:
    tuple val(sample_id), path("samples/${sample_id}/medaka/consensus.fasta"), emit: consensus

    script:
    """
    mkdir -p "samples/${sample_id}/medaka"
    
    echo "MEDAKA DEBUG:"
    echo "Sample: $sample_id"
    echo "Fastq: $fastq"
    echo "Assembly: $assembly"
    echo "Basecaller: $basecaller"
    echo "Using GPU: ${params.enable_gpu}"

    bash ${params.scripts_dir}/medaka.sh "${fastq}" "${assembly}" "samples/${sample_id}/medaka" "${task.cpus}" "${basecaller}"
    """
}