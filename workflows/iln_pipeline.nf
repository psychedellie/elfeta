#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { NORMALIZE_SHORTREADS } from '../modules/utils/normalization.nf'
include { FASTP }                from '../modules/qc/fastp.nf'      
include { SHOVILL }              from '../modules/assembly/shovill.nf'      
include { QUAST }                from '../modules/assembly/quast_iln.nf'
include { BAKTA }                from '../modules/typing/bakta.nf'
include { RMLST }                from '../modules/typing/rmlst.nf'
include { MLST }                 from '../modules/typing/mlst.nf'
include { AMRFINDERPLUS }        from '../modules/typing/amrfinderplus.nf'
include { PLASMIDFINDER }        from '../modules/typing/plasmidfinder.nf'
include { RESULTS_PUBLISHER }    from '../modules/utils/results_publisher.nf'

workflow ILN_PIPELINE {

    main:
        channel.fromPath(params.input_dir).view { file -> "input_dir = ${file}" }

        norm_out = NORMALIZE_SHORTREADS(file(params.input_dir))

        fastp_out = FASTP(norm_out.samples_tsv.map { tsv_file -> 
        file(tsv_file).parent 
        })

        def hq_reads = fastp_out.filtered
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

        hq_reads.view { sample_id, r1, r2 -> 
            "HQ Reads for Shovill - Sample_ID: $sample_id, R1: ${r1?.name}, R2: ${r2?.name}" 
        }

        shovill_out = SHOVILL(hq_reads)

        shovill_out.assembly.view { sample_id, assembly_file -> 
            "Shovill assembly - sample: $sample_id, file: $assembly_file, exists: ${file(assembly_file).exists()}" 
        }

        def quast_input = hq_reads
            .join(shovill_out.assembly)
            .map { sample_id, r1, r2, assembly_file ->
                tuple(sample_id, r1, r2, assembly_file)
            }

        QUAST(quast_input)

        def bakta_input = shovill_out.assembly
            .map { sample_id, assembly_file ->
                tuple(sample_id, assembly_file)
            }

        BAKTA(bakta_input)

        def rmlst_input = shovill_out.assembly
            .map { sample_id, assembly_file -> 
                tuple(sample_id, assembly_file) }
        RMLST(rmlst_input)

        def mlst_input = shovill_out.assembly
            .map { sample_id, assembly_file -> 
                tuple(sample_id, assembly_file) }
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

        def results_input = channel.empty()

        results_input = results_input
            .mix(AMRFINDERPLUS.out.amrf.map { sid, f -> tuple(sid, f, 'AMRFinderPlus', params.mode) })
            .mix(MLST.out.mlst.map { sid, f -> tuple(sid, f, 'MLST', params.mode) })
            .mix(PLASMIDFINDER.out.txt.map { sid, f -> tuple(sid, f, 'PlasmidFinder', params.mode) })
            .mix(QUAST.out.metrics.map { sid, f -> tuple(sid, f, 'QUAST', params.mode) })
            .mix(BAKTA.out.tsv.map { sid, f -> tuple(sid, f, 'Bakta', params.mode)})
            .mix(BAKTA.out.faa.map { sid, f -> tuple(sid, f, 'Bakta', params.mode) })
            .mix(BAKTA.out.gbff.map { sid, f -> tuple(sid, f, 'Bakta', params.mode) })
            .mix(RMLST.out.tsv.map { sid, f -> tuple(sid, f, 'rMLST', params.mode) })

        RESULTS_PUBLISHER(results_input)

    emit:
        filtered_reads = hq_reads
        assembly       = shovill_out.assembly
        annotation     = BAKTA.out.annot
        MLST           = MLST.out.mlst
        metrics        = QUAST.out.metrics
        amrfinderplus  = AMRFINDERPLUS.out.amrf
        plasmidfinder  = PLASMIDFINDER.out.plasmid
        published_files = RESULTS_PUBLISHER.out.published_file
}