process DB_VIRULENCEFINDER {
    tag "VirulenceFinder Database"
    label "db_setup"

    conda "${params.envs_dir}/git.yaml"

    publishDir "${params.db_root}", mode: 'move'

    output:
        path("virulencefinder"), emit: db_path

    script:
    """
    target_dir="${params.db_root}/virulencefinder"

    echo "Checking for existing VirulenceFinder database at: \$target_dir"
        echo "Cloning VirulenceFinder database..."
        git clone https://bitbucket.org/genomicepidemiology/virulencefinder_db.git virulencefinder_db
        mv virulencefinder_db virulencefinder
        echo "Finished cloning VirulenceFinder database."
    """
}