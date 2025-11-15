process DB_AMRFINDER {
    tag "AMRFinderPlus Database"
    label "db_setup"
    conda "${params.envs_dir}/amrfinderplus.yaml"

    publishDir "${params.db_root}", mode: 'move', symlink: true

    output:
    path("amrfinder-db"), emit: db_path

    script:
    """
    mkdir -p ${params.db_root}/amrfinder-db
    echo "Setting up AMRFinderPlus at ${params.db_root}/amrfinder-db..."
    amrfinder_update --database amrfinder-db
    """
}