process DB_BAKTA {
    tag "Bakta Database"
    label "db_setup"

    conda "${params.envs_dir}/bakta.yaml"

    publishDir "${params.db_root}", mode: 'move'

    output:
        path("bakta"), emit: db_path

    script:
    """
        echo "Downloading Bakta database into local work directory..."
        bakta_db download --type ${params.bakta_db_type}

        # Rename whatever Bakta produced (db or db-light) to bakta/
        if [ -d "db" ]; then
            mv db bakta
        elif [ -d "db-light" ]; then
            mv db-light bakta
        else
            echo "Warning: Bakta did not produce 'db' or 'db-light' directories."
            mkdir -p bakta
        fi

        echo "Finished downloading Bakta database."
    """
}