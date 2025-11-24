process AMRFINDER_HTML {
    tag "AMRFinderPlus_Report"
    
    publishDir "${params.output_dir}/Results/AMRFinderPlus/", mode: 'copy'

    input:
    path(amr_files)

    output:
    path "amrfinderplus_report.html", emit: amrfinder_html

    script:    
    """
    bash ${params.scripts_dir}/generate_html.sh \
     --files ${amr_files.join(' ')} \
     --output amrfinderplus_report.html 
    """
}