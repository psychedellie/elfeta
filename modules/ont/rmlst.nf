process RMLST {
    tag "rMLST on $sample_id"
    label 'speciator'
    
    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(sample_id), path(consensus)
    
    output:
    tuple val(sample_id), file("flye/${sample_id}/${sample_id}_rmlst.tsv"), emit: tsv
    tuple val(sample_id), file("flye/${sample_id}/${sample_id}.species"), emit: species

    script:
    // --- ΔΙΟΡΘΩΣΗ ΕΔΩ ---
    // Προσθέτουμε το ${projectDir} για να δημιουργήσουμε μια απόλυτη διαδρομή
    def organism_file = "${projectDir}/scripts/config/supported_organisms.yaml"

    """
    bash ${projectDir}/scripts/run_rmlst.sh \
        "${consensus}" \
        "flye/${sample_id}/${sample_id}_rmlst.tsv" \
        ${organism_file} \
        "flye/${sample_id}/${sample_id}.species"
    """
}