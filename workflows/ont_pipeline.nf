#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { MERGE_FASTQS }        from '../modules/ont/merge_fastqs.nf'
include { FASTPLONG }           from '../modules/ont/fastplong.nf'
include { FLYE }                from '../modules/ont/flye.nf'
include { MEDAKA }              from '../modules/ont/medaka.nf'
include { BAKTA }               from '../modules/hbd/bakta.nf'
include { QUAST }               from '../modules/ont/quast.nf'
include { RMLST }               from '../modules/hbd/rmlst.nf'
include { MLST }                from '../modules/hbd/mlst.nf'
include { AMRFINDERPLUS }       from '../modules/hbd/amrfinderplus.nf'
include { PLASMIDFINDER }       from '../modules/hbd/plasmidfinder.nf'
include { RESULTS_PUBLISHER }   from '../modules/hbd/results_publisher.nf'


workflow ONT_PIPELINE {

    main:
        channel.fromPath(params.input_dir).view { file -> "input_dir = ${file}" }

        def reads_ch

if ( file(params.input_dir).toFile().listFiles().find { file -> file.name.startsWith('barcode') } ) {
    
    merge_out_ch = MERGE_FASTQS(file(params.input_dir), file(params.sample_sheet)).out
    
    reads_ch = merge_out_ch
        .flatten()
        .map { merged_file -> 
            
            def combined_id = file(merged_file.baseName).baseName.trim() // Now e.g., "837"
            
            // --- ROBUST FIX: Handle "837" or "658_837" ---
            def sample_id = combined_id
            if (combined_id.contains('_')) {
                sample_id = combined_id.split('_')[-1] // Gets "837"
            }
            // --- END FIX ---
            
            def merged_dir = merged_file.getParent() 

            println "Processing (Merged): Combined ID ${combined_id} -> Using Sample_ID ${sample_id}"
            return tuple(sample_id, file(merged_dir)) 
        }
}
else {
    def representative_file = file(params.input_dir).toFile().listFiles().find { file -> file.name.endsWith('.fastq.gz') }

    if (!representative_file) {
        // --- TYPO FIX: params.inputdir -> params.input_dir ---
        error "No .fastq.gz files found in input directory: ${params.input_dir}"
    }

    def combined_id = file(representative_file.baseName).baseName.trim() // e.g., "837"

    // --- ROBUST FIX: Handle "837" or "658_837" ---
    def sample_id = combined_id
    if (combined_id.contains('_')) {
        sample_id = combined_id.split('_')[-1] // Gets "837"
    }
    // --- END FIX ---

    println "Processing (Direct): Combined ID ${combined_id} -> Using Sample_ID ${sample_id}"
    reads_ch = channel.value( tuple(sample_id, file(params.input_dir)) )
}

reads_ch.view { row -> "Final input - Sample_ID: ${row[0]}, Directory: ${row[1]}.name" }

fastp_out = FASTPLONG( reads_ch.map { row -> row[1] }.unique() )

def hq_reads = fastp_out.filtered
    .flatten() 
    .map { hq_file ->
        def base = file(hq_file.baseName).baseName
        def combined_id = base.replace('.hq', '').trim() // e.g., "837"
        
        // --- ROBUST FIX: Handle "837" or "658_837" ---
        def sample_id = combined_id
        if (combined_id.contains('_')) {
            sample_id = combined_id.split('_')[-1] // Gets "837"
        }
        // --- END FIX ---
        
        println "HQ Reads: Combined ID ${combined_id} -> Using Sample_ID ${sample_id}"
        return tuple(sample_id, hq_file)
    }

hq_reads.view { row -> "HQ Reads for FLYE - Sample_ID: ${row[0]}, File: ${row[1].name}" }

flye_out = FLYE(hq_reads)

        flye_out.assembly.view { row -> "FLYE assembly DETAILED - sample: ${row[0]}, file: ${row[1]}, exists: ${file(row[1]).exists()}" }

        def medaka_input = hq_reads
            .join(flye_out.assembly)
            .map { sample_id, reads_file, assembly_file ->
                println "Medaka input DETAILED - sample: $sample_id, reads: $reads_file, assembly_file: $assembly_file, assembly_exists: ${assembly_file.exists()}"
                tuple(sample_id, reads_file, assembly_file, params.basecaller)
            }

        MEDAKA(medaka_input)

        def quast_input = hq_reads
            .join(MEDAKA.out.consensus)
            .map { sample_id, reads_file, consensus_file ->
                tuple(sample_id, reads_file, consensus_file)
            }
        QUAST(quast_input)

        def bakta_input = MEDAKA.out.consensus
            .map { sample_id, consensus_file ->
                tuple(sample_id, consensus_file, params.db_root)
            }

        BAKTA(bakta_input)

        def rmlst_input = MEDAKA.out.consensus
            .map { sample_id, consensus_file ->
                tuple(sample_id, consensus_file)
            }

        RMLST(rmlst_input)

        def mlst_input = MEDAKA.out.consensus
            .map { sample_id, consensus_file ->
                    tuple(sample_id, consensus_file)
                }
        MLST(mlst_input)

        def amrfinder_input = MEDAKA.out.consensus
            .join(RMLST.out.species)
            .map { sample_id, consensus_file, species_file ->
                    tuple(sample_id, consensus_file, species_file)
                }
        AMRFINDERPLUS(amrfinder_input)

        def plasmidfinder_input = MEDAKA.out.consensus
            .map { sample_id, consensus_file ->
                tuple(sample_id, consensus_file, params.db_root)
            }

        PLASMIDFINDER(plasmidfinder_input)

        def results_input = channel.empty()

        // *** THIS IS THE CRITICAL BLOCK THAT MUST BE SAVED ***
        // It must send 4 elements: (sid, f, tool_name, params.mode)
        results_input = results_input
            .mix(MEDAKA.out.consensus.map { sid, f -> tuple(sid, f, 'Fasta', params.mode) })
            .mix(AMRFINDERPLUS.out.amrf.map { sid, f -> tuple(sid, f, 'AMRFinderPlus', params.mode) })
            .mix(MLST.out.mlst.map { sid, f -> tuple(sid, f, 'MLST', params.mode) })
            .mix(PLASMIDFINDER.out.txt.map { sid, f -> tuple(sid, f, 'PlasmidFinder', params.mode) })
            .mix(QUAST.out.metrics.map { sid, f -> tuple(sid, f, 'QUAST', params.mode) })
            .mix(BAKTA.out.tsv.map { sid, f -> tuple(sid, f, 'Bakta', params.mode)})
            .mix(BAKTA.out.faa.map { sid, f -> tuple(sid, f, 'Bakta', params.mode) })
            .mix(RMLST.out.tsv.map { sid, f -> tuple(sid, f, 'rMLST', params.mode) })

        RESULTS_PUBLISHER(results_input)

    emit:
        filtered_reads = hq_reads
        assembly = MEDAKA.out.consensus
        annotation = BAKTA.out.annot
        MLST = MLST.out.mlst
        metrics = QUAST.out.metrics
        amrfinderplus = AMRFINDERPLUS.out.amrf
        plasmidfinder = PLASMIDFINDER.out.plasmid
        published_files = RESULTS_PUBLISHER.out.published_file
}