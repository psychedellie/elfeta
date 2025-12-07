process DB_PLASMIDFINDER {
    tag "PlasmidFinder Database"
    label "db_setup"

    conda "${params.envs_dir}/git.yaml"

    publishDir "${params.db_root}", mode: 'move'

    output:
        path("plasmidfinder"), emit: db_path

    script:
    """
    target_dir="${params.db_root}/plasmidfinder"

    echo "Checking for existing PlasmidFinder database at: \$target_dir"
        echo "Cloning PlasmidFinder database..."
        git clone https://bitbucket.org/genomicepidemiology/plasmidfinder_db.git plasmidfinder_db
        mv plasmidfinder_db plasmidfinder
        echo "Finished cloning PlasmidFinder database."
    """
}