#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// --- All includes are fine here ---
include { showHelp }       from './workflows/help_utils.nf'
include { validateParams } from './workflows/help_utils.nf'
include { dbSetup }        from './workflows/db_setup.nf'
include { ONT_PIPELINE }   from './workflows/ont_pipeline.nf'
include { ILN_PIPELINE }   from './workflows/iln_pipeline.nf'
include { HBD_PIPELINE }   from './workflows/hbd_pipeline.nf'
include { REPORT }         from './modules/utils/report.nf'

// --- Helper function(s) ---
def absPath(p) {
    if (!p) return null
    def f = file(p)
    return f.exists() ? f.toRealPath().toString() : f.toAbsolutePath().toString()
}

// --- Parameter initialization function ---
def initParams() {
    params.input_dir   = absPath(params.input_dir)
    params.output_dir  = absPath(params.output_dir)
    params.db_root     = absPath(params.db_root)
    params.scripts_dir = absPath(params.scripts_dir)
    params.envs_dir    = absPath(params.envs_dir)

    if (params.db_root) {
        params.amrfinder_db     = "${params.db_root}/amrfinder"
        params.bakta_db         = (params.bakta_db_type == 'light') ? "${params.db_root}/db-light" : "${params.db_root}/db"
        params.plasmidfinder_db = "${params.db_root}/plasmidfinder_db"
    } else {
        params.amrfinder_db     = null
        params.bakta_db         = null
        params.plasmidfinder_db = null
    }

    return params
}

// --- Main logic workflow ---
workflow {
    
    if (params.help || params.h) {
        showHelp()  
        exit 0
    }

    if (params.db_setup) {
        dbSetup()
        return
    }

    validateParams(params)

    def sample_sheet = channel.of(file(params.sample_sheet))

    if (params.mode == 'ont') {
        def ont_results = ONT_PIPELINE()
        def all_completed = ont_results.published_files.collect()
        REPORT(file(params.output_dir), sample_sheet, all_completed, params.mode)
    }

    if (params.mode == 'iln') {
        def iln_results = ILN_PIPELINE()
        def all_completed = iln_results.published_files.collect()
        REPORT(file(params.output_dir), sample_sheet, all_completed, params.mode)
    }

    if (params.mode == 'hbd') {
        def hbd_results = HBD_PIPELINE()
        def all_completed = hbd_results.published_files.collect()
        REPORT(file(params.output_dir), sample_sheet, all_completed, params.mode)
    }
}
