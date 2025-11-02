#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { ONT_PIPELINE } from './workflows/ont_pipeline.nf'

workflow {
    if (params.mode == 'ont') {
        ONT_PIPELINE()   
    } else {
        error "Unknown mode: ${params.mode}"
    }
}
