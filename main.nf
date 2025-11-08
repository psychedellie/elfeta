#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// --- Helper to make paths absolute relative to the launch directory ---
def absPath(p) {
    if (!p) return null
    def f = file(p)
    return f.exists() ? f.toRealPath().toString() : f.toAbsolutePath().toString()
}

// Normalize key path parameters
params.input_dir   = absPath(params.input_dir)
params.outdir      = absPath(params.outdir)
params.db_root     = absPath(params.db_root)
params.scripts_dir = absPath(params.scripts_dir)
params.envs_dir    = absPath(params.envs_dir)

include { ONT_PIPELINE }   from './workflows/ont_pipeline.nf'
include { ILN_PIPELINE }   from './workflows/iln_pipeline.nf'
include { REPORT }         from './modules/hbd/report.nf'

workflow {

    def sample_sheet = channel.of(file(params.sample_sheet))

    if (params.mode == 'ont') {
        def ont_results = ONT_PIPELINE()
        
        // CHANGED: Create a completion channel that waits for ALL outputs
        // This now collects the actual published files channel
        def all_completed = ont_results.published_files
            .collect()
            .first()
        
        // CHANGED: REPORT waits for all processes to complete
        // Pass the main params.outdir instead of the non-existent channel
        // AND pass params.mode
        REPORT(file(params.outdir), sample_sheet, all_completed, params.mode)
    }

    if (params.mode == 'iln') {
        def iln_results = ILN_PIPELINE()
        
        // CHANGED: Create a completion channel that waits for ALL outputs
        // This now collects the actual published files channel
        // NOTE: This assumes 'iln_pipeline.nf' is changed in the same way as 'ont_pipeline.nf'
        def all_completed = iln_results.published_files
            .collect()
            .first()
            
        // CHANGED: REPORT waits for all processes to complete
        // Pass the main params.outdir instead of the non-existent channel
        // AND pass params.mode
        REPORT(file(params.outdir), sample_sheet, all_completed, params.mode)
    }
}