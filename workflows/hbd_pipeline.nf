#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { NORMALIZE_SHORTREADS } from '../modules/utils/normalization.nf'
include { MERGE_FASTQS }         from '../modules/utils/merge_fastqs.nf'
include { FASTP }                from '../modules/qc/fastp.nf'
include { FASTPLONG }            from '../modules/qc/fastplong.nf'
include { FLYE }                 from '../modules/assembly/flye.nf'
include { MEDAKA }               from '../modules/assembly/medaka.nf'
include { BWA_INDEX }            from '../modules/assembly/bwa_index.nf'
include { BWA_MEM }              from '../modules/assembly/bwa_mem.nf'
include { POLYPOLISH }           from '../modules/assembly/polypolish.nf'
include { QUAST }                from '../modules/assembly/quast_iln.nf'
include { BAKTA }                from '../modules/typing/bakta.nf'
include { RMLST }                from '../modules/typing/rmlst.nf'
include { MLST }                 from '../modules/typing/mlst.nf'
include { AMRFINDERPLUS }        from '../modules/typing/amrfinderplus.nf'
include { PLASMIDFINDER }        from '../modules/typing/plasmidfinder.nf'
include { RESULTS_PUBLISHER }    from '../modules/utils/results_publisher.nf'

workflow HBD_PIPELINE {

    main:
        channel.fromPath(params.input_dir).view { file -> "input_dir = ${file}" }

        norm_out = NORMALIZE_SHORTREADS(file(params.input_dir))

        fastp_out = FASTP(norm_out.samples_tsv.map { tsv_file -> 
            file(tsv_file).parent 
        })

        def hq_reads_iln = fastp_out.filtered
            .flatten() 
            .map { hq_file ->
                def base = file(hq_file.baseName).baseName
                def sample_id = base.replace('_R1.hq', '').replace('_R2.hq', '').trim()
                return tuple(sample_id, hq_file)
            }
            .groupTuple()
            .map { sample_id, files ->
                def r1 = files.find { file -> file.name.contains('_R1.hq.fastq.gz') }
                def r2 = files.find { file -> file.name.contains('_R2.hq.fastq.gz') }
                tuple(sample_id, r1, r2)
            }

        hq_reads_iln.view { sample_id, r1, r2 -> 
            "HQ Reads for bwa-mem2 - Sample_ID: $sample_id, R1: ${r1?.name}, R2: ${r2?.name}"
        }

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

        def hq_reads_ont = fastplong_out.filtered
            .flatten()
            .filter { hq_file ->  
                !hq_file.name.contains('_R1.hq') && !hq_file.name.contains('_R2.hq')
            }                     
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

        hq_reads_ont.view { row -> "HQ Reads for FLYE - Sample_ID: ${row[0]}, File: ${row[1].name}" }

        flye_out = FLYE(hq_reads_ont)

        def medaka_input = hq_reads_ont
            .join(flye_out.assembly)
            .map { sample_id, fastq, assembly_file ->
                println "Medaka input DETAILED - sample: $sample_id, reads: $fastq, assembly_file: $assembly_file, assembly_exists: ${assembly_file.exists()}"
                tuple(sample_id, fastq, assembly_file, params.basecaller)
            }

        medaka_out = MEDAKA(medaka_input)

        def bwa_ind_input = medaka_out.consensus
        bwa_index_out = BWA_INDEX(bwa_ind_input) 
        
        def bwa_mem_input = bwa_index_out.index.join(hq_reads_iln)
        
        bwa_mem_out = BWA_MEM(bwa_mem_input)

// 1. Join the bam and bai channels from BWA_MEM
def bwa_alignments = bwa_mem_out.bam.join(bwa_mem_out.bai)
// bwa_alignments channel is now: [sample_id, bam_file, bai_file]

// 2. Join assembly with alignments, then add args
def polypolish_input = medaka_out.consensus
    .join(bwa_alignments)
    .map { sample_id, assembly, bam, bai ->
        // Create the 5-part tuple that your module expects
        tuple(sample_id, assembly, bam, bai, params.polypolish_args) 
    }
polypolish_out = POLYPOLISH(polypolish_input)

        def final_assembly = polypolish_out.assembly
        final_assembly.view { sample_id, final_assembly_file ->
            "Hybrid Assembly Complete - Sample: $sample_id, Assembly: ${final_assembly_file.name}"
        }

        def results_input = channel.empty()
        results_input = results_input
            .mix(final_assembly.map { sid, f -> tuple(sid, f, 'Fasta', params.mode) })

        RESULTS_PUBLISHER(results_input)


    emit:
        filtered_ont_reads = hq_reads_ont
        filtered_iln_reads = hq_reads_iln
        assembly           = final_assembly       
        published_files    = RESULTS_PUBLISHER.out.published_file 
        annotation         = channel.empty()
        MLST               = channel.empty()
        metrics            = channel.empty()
        amrfinderplus      = channel.empty()
        plasmidfinder      = channel.empty()
        }
        
        
    
