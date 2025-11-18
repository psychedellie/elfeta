#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { MERGE_FASTQS }        from '../modules/utils/merge_fastqs.nf'
include { FASTPLONG }           from '../modules/qc/fastplong.nf'
include { FLYE }                from '../modules/assembly/flye.nf'
include { MEDAKA }              from '../modules/assembly/medaka.nf'
include { QUAST }               from '../modules/assembly/quast_ont.nf'
include { BAKTA }               from '../modules/typing/bakta.nf'
include { RMLST }               from '../modules/typing/rmlst.nf'
include { MLST }                from '../modules/typing/mlst.nf'
include { AMRFINDERPLUS }       from '../modules/typing/amrfinderplus.nf'
include { PLASMIDFINDER }       from '../modules/typing/plasmidfinder.nf'
include { RESULTS_PUBLISHER }   from '../modules/utils/results_publisher.nf'


workflow ONT_PIPELINE {

    main:
        channel.fromPath(params.input_dir).view { file -> "input_dir = ${file}" }

        def reads_ch

if ( file(params.input_dir).toFile().listFiles().find { file -> file.name.startsWith('barcode') } ) {
    
    merge_out_ch = MERGE_FASTQS(file(params.input_dir), file(params.sample_sheet)).out
    
    reads_ch = merge_out_ch
        .flatten()
        .map { merged_file -> 
            
            def combined_id = file(merged_file.baseName).baseName.trim()
            def sample_id = combined_id
            if (combined_id.contains('_')) {
                sample_id = combined_id.split('_')[-1]
            }
            
            def merged_dir = merged_file.getParent() 

            println "Processing (Merged): Combined ID ${combined_id} -> Using Sample_ID ${sample_id}"
            return tuple(sample_id, file(merged_dir)) 
        }
}
else {
    def representative_file = file(params.input_dir).toFile().listFiles().find { file -> file.name.endsWith('.fastq.gz') }

    if (!representative_file) {
        error "No .fastq.gz files found in input directory: ${params.input_dir}"
    }

    def combined_id = file(representative_file.baseName).baseName.trim()
    def sample_id = combined_id
    if (combined_id.contains('_')) {
        sample_id = combined_id.split('_')[-1] 
    }

    println "Processing (Direct): Combined ID ${combined_id} -> Using Sample_ID ${sample_id}"
    reads_ch = channel.value( tuple(sample_id, file(params.input_dir)) )
}

reads_ch.view { row -> "Final input - Sample_ID: ${row[0]}, Directory: ${row[1]}.name" }

fastplong_out = FASTPLONG( reads_ch.map { row -> row[1] }.unique() )

def hq_reads = fastplong_out.filtered
    .flatten() 
    .map { hq_file ->
        def base = file(hq_file.baseName).baseName
        def combined_id = base.replace('.hq', '').trim()
        
        def sample_id = combined_id
        if (combined_id.contains('_')) {
            sample_id = combined_id.split('_')[-1]
        }
        
        println "HQ Reads: Combined ID ${combined_id} -> Using Sample_ID ${sample_id}"
        return tuple(sample_id, hq_file)
    }

hq_reads.view { row -> "HQ Reads for FLYE - Sample_ID: ${row[0]}, File: ${row[1].name}" }

flye_out = FLYE(hq_reads)

        flye_out.assembly.view { row -> "FLYE assembly DETAILED - sample: ${row[0]}, file: ${row[1]}, exists: ${file(row[1]).exists()}" }

        def medaka_in = hq_reads
            .join(flye_out.assembly)
            .map { sample_id, fastq, assembly_file ->
                println "Medaka input DETAILED - sample: $sample_id, reads: $fastq, assembly_file: $assembly_file, assembly_exists: ${assembly_file.exists()}"
                tuple(sample_id, fastq, assembly_file, params.basecaller)
            }

        MEDAKA(medaka_in)

        def final_assembly = MEDAKA.out.consensus

        def quast_in = hq_reads
            .join(final_assembly)
            .map { sample_id, fastq, consensus_file ->
                return tuple( sample_id, fastq, consensus_file )
            }
        QUAST(quast_in)

        def bakta_in = final_assembly
            .map { sample_id, consensus_file ->
                tuple(sample_id, consensus_file)
            }

        BAKTA(bakta_in)

        def rmlst_in = final_assembly
            .map { sample_id, consensus_file ->
                tuple(sample_id, consensus_file)
            }

        RMLST(rmlst_in)

        def mlst_in = final_assembly
            .map { sample_id, consensus_file ->
                    tuple(sample_id, consensus_file)
                }
        MLST(mlst_in)

        def amrfinder_in = final_assembly
            .join(RMLST.out.species)
            .map { sample_id, consensus_file, species_file ->
                    tuple(sample_id, consensus_file, species_file)
                }
        AMRFINDERPLUS(amrfinder_in)

        def plasmidfinder_in = final_assembly
            .map { sample_id, consensus_file ->
                tuple(sample_id, consensus_file, params.db_root)
            }

        PLASMIDFINDER(plasmidfinder_in)

        def results_in = channel.empty()

        results_in = results_in
            .mix(FLYE.out.info.map { sid, f -> tuple(sid, f, 'Fasta/assembly_info', params.mode) })
            .mix(final_assembly.map { sid, f -> tuple(sid, f, 'Fasta', params.mode) })
            .mix(AMRFINDERPLUS.out.amrf.map { sid, f -> tuple(sid, f, 'AMRFinderPlus', params.mode) })
            .mix(MLST.out.mlst.map { sid, f -> tuple(sid, f, 'MLST', params.mode) })
            .mix(PLASMIDFINDER.tsv.map { sid, f -> tuple(sid, f, 'PlasmidFinder', params.mode) })
            .mix(QUAST.out.metrics.map { sid, f -> tuple(sid, f, 'QUAST', params.mode) })
            .mix(BAKTA.out.tsv.map { sid, f -> tuple(sid, f, 'Bakta', params.mode)})
            .mix(BAKTA.out.faa.map { sid, f -> tuple(sid, f, 'Bakta', params.mode) })
            .mix(BAKTA.out.gbff.map { sid, f -> tuple(sid, f, 'Bakta', params.mode) })
            .mix(RMLST.out.tsv.map { sid, f -> tuple(sid, f, 'rMLST', params.mode) })

        RESULTS_PUBLISHER(results_in)

    emit:
        filtered_reads = hq_reads
        assembly = final_assembly
        annotation = BAKTA.out.annot
        MLST = MLST.out.mlst
        metrics = QUAST.out.metrics
        amrfinderplus = AMRFINDERPLUS.out.amrf
        plasmidfinder = PLASMIDFINDER.out.plasmid
        published_files = RESULTS_PUBLISHER.out.published_file
}