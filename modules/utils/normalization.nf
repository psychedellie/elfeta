process NORMALIZE_SHORTREADS {
    tag "normalize_shortreads"
    label 'preprocessing'
    publishDir "${params.output_dir}/normalized_fastqs", mode: 'copy'

    input:
        path input_dir

    output:
        path "samples.tsv",  emit: tsv
        path "*.fastq.gz",   emit: fastqs

    script:
        """
        in_dir=\$(realpath "${input_dir}")
        
        bash ${params.scripts_dir}/normalize_shortreads.sh "\$in_dir" "." || {
            exit 1
        }
        """
}