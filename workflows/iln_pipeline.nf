#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { NORMALIZE_SHORTREADS } from '../modules/iln/normalization.nf'
include { FASTP }                from '../modules/iln/fastp.nf'      
include { SHOVILL }              from '../modules/iln/shovill.nf'      
include { QUAST }                from '../modules/iln/quast.nf'
include { BAKTA }                from '../modules/hbd/bakta.nf'
include { RMLST }                from '../modules/hbd/rmlst.nf'
include { MLST }                 from '../modules/hbd/mlst.nf'
include { AMRFINDERPLUS }        from '../modules/hbd/amrfinderplus.nf'
include { PLASMIDFINDER }        from '../modules/hbd/plasmidfinder.nf'
include { RESULTS_PUBLISHER }    from '../modules/hbd/results_publisher.nf'

workflow ILN_PIPELINE {

    main:
        // ---- Step 1: Normalize (only creates samples.tsv) ----
        NORMALIZE_SHORTREADS(file(params.input_dir))

        // ---- Step 2: Pass the ORIGINAL input directory to FASTP ----
        fastp_out = FASTP(file(params.input_dir))

        // ---- Step 3: Process FASTP filtered reads for Shovill ----
        // This matches the ONT pipeline structure exactly
        def hq_reads = fastp_out.filtered
            .flatten() 
            .map { hq_file ->
                def base = file(hq_file.baseName).baseName
                def sample_id = base.replace('_R1.hq', '').replace('_R2.hq', '').trim()
                return tuple(sample_id, hq_file)
            }
            .groupTuple()
            .map { sample_id, files ->
                // For Illumina, we need to pair R1 and R2 files
                def r1 = files.find { file -> file.name.contains('_R1.hq.fastq.gz') }
                def r2 = files.find { file -> file.name.contains('_R2.hq.fastq.gz') }
                tuple(sample_id, r1, r2)
            }

        hq_reads.view { sample_id, r1, r2 -> 
            "HQ Reads for Shovill - Sample_ID: $sample_id, R1: ${r1?.name}, R2: ${r2?.name}" 
        }

        // ---- Assembly with Shovill ----
        shovill_out = SHOVILL(hq_reads)

        shovill_out.assembly.view { sample_id, assembly_file -> 
            "Shovill assembly - sample: $sample_id, file: $assembly_file, exists: ${file(assembly_file).exists()}" 
        }

        // ---- QUAST (reads + assembly) ----
        def quast_input = hq_reads
            .join(shovill_out.assembly)
            .map { sample_id, r1, r2, assembly_file ->
                tuple(sample_id, r1, r2, assembly_file)
            }

        QUAST(quast_input)

        // ---- Annotation ----
        def bakta_input = shovill_out.assembly
            .map { sample_id, assembly_file ->
                tuple(sample_id, assembly_file, params.db_root)
            }

        BAKTA(bakta_input)

        // ---- Typing & resistance ----
        def rmlst_input = shovill_out.assembly
            .map { sample_id, assembly_file -> tuple(sample_id, assembly_file) }
        RMLST(rmlst_input)

        def mlst_input = shovill_out.assembly
            .map { sample_id, assembly_file -> tuple(sample_id, assembly_file) }
        MLST(mlst_input)

        def amrfinder_input = shovill_out.assembly
            .join(RMLST.out.species)
            .map { sample_id, assembly_file, species_file ->
                tuple(sample_id, assembly_file, species_file)
            }
        AMRFINDERPLUS(amrfinder_input)

        def plasmidfinder_input = shovill_out.assembly
            .map { sample_id, assembly_file ->
                tuple(sample_id, assembly_file, params.db_root)
            }
        PLASMIDFINDER(plasmidfinder_input)

        // ---- Collect results ----
        def results_input = channel.empty()

        results_input = results_input
            .mix(shovill_out.assembly.map { sid, f -> tuple(sid, f, 'Assembly') })
            .mix(AMRFINDERPLUS.out.amrf.map { sid, f -> tuple(sid, f, 'AMRFinderPlus') })
            .mix(MLST.out.mlst.map { sid, f -> tuple(sid, f, 'MLST') })
            .mix(PLASMIDFINDER.out.txt.map { sid, f -> tuple(sid, f, 'PlasmidFinder') })
            .mix(QUAST.out.metrics.map { sid, f -> tuple(sid, f, 'QUAST') })
            .mix(BAKTA.out.tsv.map { sid, f -> tuple(sid, f, 'Bakta') })
            .mix(RMLST.out.species.map { sid, f -> tuple(sid, f, 'rMLST') })

        RESULTS_PUBLISHER(results_input)

    emit:
        filtered_reads = hq_reads
        assembly       = shovill_out.assembly
        annotation     = BAKTA.out.annot
        MLST           = MLST.out.mlst
        metrics        = QUAST.out.metrics
        amrfinderplus  = AMRFINDERPLUS.out.amrf
        plasmidfinder  = PLASMIDFINDER.out.plasmid
        results_dir    = RESULTS_PUBLISHER.out.results_dir
}