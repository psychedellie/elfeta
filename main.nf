#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include { SHOW_HELP }               from './workflows/utils/help_utils.nf'
include { VAL_PARAMS }              from './workflows/utils/val_params.nf'
include { DB_SETUP }                from './workflows/utils/db_setup.nf'
include { ONT_PIPELINE }            from './workflows/main/ont_pipeline.nf'
include { ILN_PIPELINE }            from './workflows/main/iln_pipeline.nf'
include { SP_PIPELINE }             from './workflows/main/sp_pipeline.nf'
include { LP_PIPELINE }             from './workflows/main/lp_pipeline.nf'
include { REPORT }                  from './modules/utils/report.nf'
include { AMRFINDER_HTML }          from './modules/utils/amrfinder_html.nf'

def absPath(p) {
    if (!p) return null

    def f = file(p)

    return f.exists()
        ? f.toRealPath().toString()
        : f.toAbsolutePath().toString()
}

def initParams() {

    params.input_dir    = absPath(params.input_dir)
    params.output_dir   = absPath(params.output_dir)
    params.db_root      = absPath(params.db_root)
    params.scripts_dir  = absPath(params.scripts_dir)
    params.envs_dir     = absPath(params.envs_dir)
    params.assembly_dir = params.assembly_dir ? absPath(params.assembly_dir) : null

    if (params.db_root) {
        params.amrfinder_db = "${params.db_root}/amrfinder"

        params.bakta_db = params.bakta_db_type == 'light'
            ? "${params.db_root}/db-light"
            : "${params.db_root}/db"

        params.plasmidfinder_db = "${params.db_root}/plasmidfinder_db"

        params.virulencefinder_db = "${params.db_root}/virulencefinder_db"

    } else {
        params.amrfinder_db = null
        params.bakta_db = null
        params.plasmidfinder_db = null
        params.virulencefinder_db = null
    }

    return params
}

workflow {

    initParams()

    if (params.help || params.h) {
        SHOW_HELP()
        exit 0
    }

    if (params.db_setup) {
        DB_SETUP()
        return
    }

    VAL_PARAMS(params)

    def sample_sheet = channel.of(file(params.sample_sheet))

    def assembly_dir_to_pass = ''

    if (params.mode == 'ont' || params.mode == 'sp') {
        if (params.assembly_dir) {
            assembly_dir_to_pass = file(params.assembly_dir).toString()
        } else {
            assembly_dir_to_pass = "${params.output_dir}/Results/AssemblyMetrics"
        }
    } else {
        assembly_dir_to_pass = ''
    }

    if (params.mode == 'ont') {

        def ont_results = ONT_PIPELINE()

        def amrfinder_files = ont_results.ARGs_PMs_VGs
            .map { sample_id, file -> file }
            .collect()

        def amr_html_done = AMRFINDER_HTML(amrfinder_files)

        def all_completed = ont_results.Published_Results
            .mix(amr_html_done)
            .collect()

        REPORT(
            file(params.output_dir),
            sample_sheet,
            all_completed,
            params.mode,
            assembly_dir_to_pass
        )
    }

    if (params.mode == 'iln') {

        def iln_results = ILN_PIPELINE()

        def amrfinder_files = iln_results.ARGs_PMs_VGs
            .map { sample_id, file -> file }
            .collect()

        def amr_html_done = AMRFINDER_HTML(amrfinder_files)

        def all_completed = iln_results.Published_Results
            .mix(amr_html_done)
            .collect()

        REPORT(
            file(params.output_dir),
            sample_sheet,
            all_completed,
            params.mode,
            ''
        )
    }

    if (params.mode == 'sp') {

        def sp_results = SP_PIPELINE()

        def amrfinder_files = sp_results.ARGs_PMs_VGs
            .map { sample_id, file -> file }
            .collect()

        def amr_html_done = AMRFINDER_HTML(amrfinder_files)

        def all_completed = sp_results.Published_Results
            .mix(amr_html_done)
            .collect()

        REPORT(
            file(params.output_dir),
            sample_sheet,
            all_completed,
            params.mode,
            assembly_dir_to_pass
        )
    }

    if (params.mode == 'lp') {

        def lp_results = LP_PIPELINE()

        def amrfinder_files = lp_results.ARGs_PMs_VGs
            .map { sample_id, file -> file }
            .collect()

        def amr_html_done = AMRFINDER_HTML(amrfinder_files)

        def all_completed = lp_results.Published_Results
            .mix(amr_html_done)
            .collect()

        REPORT(
            file(params.output_dir),
            sample_sheet,
            all_completed,
            params.mode,
            ''
        )
    }
}