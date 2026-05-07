process MOBTYPER {

    tag "$sample_id"
    label 'mobtyper'
    conda "${params.envs_dir}/mobtyper.yaml"

    publishDir "${params.output_dir}/logs/${sample_id}/MOBTyper", mode: 'copy', pattern: ".command.*"
    publishDir "${params.output_dir}", mode: 'copy', pattern: "samples/**"

    input:
        tuple val(sample_id), path(fasta)
        val(args)

    output:
        tuple val(sample_id), path("samples/${sample_id}/mobtyper/${sample_id}_mobtyper.tsv"), emit: tsv
        tuple val(sample_id), path("samples/${sample_id}/mobtyper"), emit: outdir
        path ".command.*", emit: nf_logs

    script:

        def outdir = "samples/${sample_id}/mobtyper"
        def outfile = "${outdir}/${sample_id}_mobtyper.tsv"

        """
        mkdir -p "${outdir}"

        mob_typer \
            -i "${fasta}" \
            -o "${outfile}" \
            -s "${sample_id}" \
            ${args}
        """
}