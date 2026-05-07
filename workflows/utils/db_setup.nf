#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { DB_AMRFINDER }       from '../../modules/utils/db_amrfinder.nf'
include { DB_BAKTA }           from '../../modules/utils/db_bakta.nf'
include { DB_PLASMIDFINDER }   from '../../modules/utils/db_plasmidfinder.nf'
include { DB_VIRULENCEFINDER } from '../../modules/utils/db_virulencefinder.nf'

workflow DB_SETUP {

    main:
        log.info """
        ========================================================
        Starting Database Setup...
        Target directory: ${params.db_root}
        ========================================================
        """

        // ensure root directory exists
        file("${params.db_root}").mkdirs()

        // optional: clean existing DBs if --force_db_update is true
        if (params.force_db_update) {
            ['amrfinder','bakta','plasmidfinder','virulencefinder'].each { name ->
                def db_dir = file("${params.db_root}/${name}")
                if (db_dir.exists()) {
                    log.info "Force update enabled: removing ${db_dir}"
                    db_dir.deleteDir()
                }
            }
        }

        // run modules conditionally
        def tasks = []

        if (!file("${params.db_root}/amrfinder").exists()) {
            log.info "Downloading AMRFinderPlus database..."
            tasks << DB_AMRFINDER()
        } else {
            log.info "AMRFinderPlus database found — skipping download."
        }

        if (!file("${params.db_root}/bakta").exists()) {
            log.info "Downloading Bakta database..."
            tasks << DB_BAKTA()
        } else {
            log.info "Bakta database found — skipping download."
        }

        if (!file("${params.db_root}/plasmidfinder").exists()) {
            log.info "Downloading PlasmidFinder database..."
            tasks << DB_PLASMIDFINDER()
        } else {
            log.info "PlasmidFinder database found — skipping download."
        }

        if (!file("${params.db_root}/virulencefinder").exists()) {
            log.info "Downloading PlasmidFinder database..."
            tasks << DB_VIRULENCEFINDER()
        } else {
            log.info "VirulenceFinder database found — skipping download."
        }

        // if all DBs exist already
        if (tasks.isEmpty()) {
            log.info """
            ========================================================
            All databases already present. Nothing to do.
            ========================================================
            """
            db_paths = channel.empty()
        } 
        else {
            // collect paths of created databases
            db_paths = channel
                .fromList(tasks)
                .flatten()

            // subscribe to trigger execution & show log output
            db_paths.view { db_item ->
                log.info """
                ========================================================
                Database setup complete.
                Database available at: ${db_item}
                ========================================================
                """
            }
        }

    emit:
        db_paths
}