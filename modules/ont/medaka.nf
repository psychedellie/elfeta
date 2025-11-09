process MEDAKA {
    tag "$sample_id"
    label 'medaka_polishing'
    publishDir "${params.outdir}", mode: 'copy'
    conda "${params.envs_dir}/medaka.yaml"

    input:
    tuple val(sample_id), path(fastq), path(assembly), val(basecaller)

    output:
    tuple val(sample_id), path("flye/${sample_id}/medaka/consensus.fasta"), emit: consensus

    script:
    """
    mkdir -p "flye/${sample_id}/medaka"
    
    # Debug the input paths
    echo "MEDAKA DEBUG:"
    echo "Sample: $sample_id"
    echo "Fastq: $fastq"
    echo "Assembly: $assembly"
    echo "Assembly exists: \$(if [ -f \"$assembly\" ]; then echo 'YES'; else echo 'NO'; fi)"
    echo "Basecaller: $basecaller"
    
    bash ${params.scripts_dir}/medaka.sh "${fastq}" "${assembly}" "flye/${sample_id}/medaka" "${task.cpus}" "${basecaller}"
    """
}