#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Include help utilities
include { showHelp } from './workflows/help_utils.nf'
include { validateParams } from './workflows/help_utils.nf'



def absPath(p) {
    if (!p) return null
    def f = file(p)
    return f.exists() ? f.toRealPath().toString() : f.toAbsolutePath().toString()
}

params.input_dir   = absPath(params.input_dir)
params.output_dir  = absPath(params.output_dir)
params.db_root     = absPath(params.db_root)
params.scripts_dir = absPath(params.scripts_dir)
params.envs_dir    = absPath(params.envs_dir)

include { ONT_PIPELINE }   from './workflows/ont_pipeline.nf'
include { ILN_PIPELINE }   from './workflows/iln_pipeline.nf'
include { REPORT }         from './modules/utils/report.nf'

workflow {
    if (params.help || params.h) {
        showHelp()  
        workflow.exit(0)
    }

    validateParams(params)

    def sample_sheet = channel.of(file(params.sample_sheet))

    if (params.mode == 'ont') {
        def ont_results = ONT_PIPELINE()
        
        def all_completed = ont_results.published_files
            .collect()
        
        REPORT(file(params.output_dir), sample_sheet, all_completed, params.mode)
    }

    if (params.mode == 'iln') {
        def iln_results = ILN_PIPELINE()

        def all_completed = iln_results.published_files
            .collect()
            
        REPORT(file(params.output_dir), sample_sheet, all_completed, params.mode)
    }
}