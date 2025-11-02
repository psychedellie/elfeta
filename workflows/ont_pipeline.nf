#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { MERGE_FASTQS } from '../modules/ont/merge_fastqs.nf'
include { FASTPLONG }   from '../modules/ont/fastplong.nf'
include { FLYE }        from '../modules/ont/flye.nf'
include { MEDAKA }      from '../modules/ont/medaka.nf'
include { BAKTA }      from '../modules/ont/bakta.nf'
include { RMLST }      from '../modules/ont/rmlst.nf'
include { QUAST }      from '../modules/ont/quast.nf'
include { MLST }      from '../modules/ont/mlst.nf'
include { AMRFINDERPLUS }      from '../modules/ont/amrfinderplus.nf'
include { PLASMIDFINDER }      from '../modules/ont/plasmidfinder.nf'
include { RESULTS_PUBLISHER } from '../modules/ont/results_publisher.nf'


workflow ONT_PIPELINE {

    main:
        channel.fromPath(params.input_dir).view { file -> "input_dir = ${file}" }

        def reads_ch

if ( file(params.input_dir).toFile().listFiles().find { file -> file.name.startsWith('barcode') } ) {
    
    merge_out_ch = MERGE_FASTQS(params.input_dir, params.sample_sheet).out
    
    reads_ch = merge_out_ch
        .flatten()
        .map { merged_file -> 
            
            def sample_id = file(merged_file.baseName).baseName.trim()
            
            def merged_dir = merged_file.getParent() 

            println "Processing (Merged): $sample_id with directory: $merged_dir.name"
            return tuple(sample_id, file(merged_dir)) 
        }
}
else {
    def representative_file = file(params.input_dir).toFile().listFiles().find { file -> file.name.endsWith('.fastq.gz') }

    if (!representative_file) {
        error "No .fastq.gz files found in input directory: ${params.input_dir}"
    }

    def sample_id = file(representative_file.baseName).baseName.trim()

    println "Processing (Direct): $sample_id with directory: $params.input_dir.name"
    reads_ch = channel.value( tuple(sample_id, file(params.input_dir)) )
}

reads_ch.view { row -> "Final input - Sample_ID: ${row[0]}, Directory: ${row[1]}.name" }

fastp_out = FASTPLONG( reads_ch.map { row -> row[1] }.unique() )

def hq_reads = fastp_out.filtered
    .flatten() 
    .map { hq_file ->
        def base = file(hq_file.baseName).baseName
        def sample_id = base.replace('.hq', '').trim()
        
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

        def quast_input = hq_reads
            .join(MEDAKA.out.consensus)
            .map { sample_id, reads_file, consensus_file ->
                tuple(sample_id, reads_file, consensus_file)
            }
        QUAST(quast_input)

        def mlst_input = MEDAKA.out.consensus
            .map { consensus_file, sample_id -> // <- ΣΩΣΤΗ ΣΕΙΡΑ
                    tuple(consensus_file, sample_id)
                }
        MLST(mlst_input)

        def amrfinder_input = MEDAKA.out.consensus
            .join(RMLST.out.species)
            .map { sample_id, consensus_file, species_file -> // <- ΣΩΣΤΗ ΣΕΙΡΑ
                    tuple(sample_id, consensus_file, species_file)
                }
        AMRFINDERPLUS(amrfinder_input)

        def plasmidfinder_input = MEDAKA.out.consensus
            .map { sample_id, consensus_file ->
                tuple(sample_id, consensus_file, params.db_root)
            }

        PLASMIDFINDER(plasmidfinder_input)

        def results_input = channel.empty()

        results_input = results_input
            .mix(MEDAKA.out.consensus.map { sid, f -> tuple(sid, f, 'Fasta') })
            .mix(AMRFINDERPLUS.out.amrf.map { sid, f -> tuple(sid, f, 'AMRFinderPlus') })
            .mix(MLST.out.mlst.map { sid, f -> tuple(sid, f, 'MLST') })
            .mix(PLASMIDFINDER.out.txt.map { sid, f -> tuple(sid, f, 'PlasmidFinder') })
            .mix(QUAST.out.metrics.map { sid, f -> tuple(sid, f, 'QUAST') })
            .mix(BAKTA.out.tsv.map { sid, f -> tuple(sid, f, 'Bakta')})
            .mix(BAKTA.out.faa.map { sid, f -> tuple(sid, f, 'Bakta') })

        RESULTS_PUBLISHER(results_input)

    emit:
        filtered_reads = hq_reads
        assembly = MEDAKA.out.consensus
        annotation = BAKTA.out.annot
        MLST = MLST.out.mlst
        metrics = QUAST.out.metrics
        amrfinderplus = AMRFINDERPLUS.out.amrf
        plasmidfinder = PLASMIDFINDER.out.plasmid
}