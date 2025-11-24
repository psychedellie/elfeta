#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// -- Modules --
include { NORMALIZE_SHORTREADS } from '../../modules/utils/normalization.nf'
include { FASTP }                from '../../modules/qc/fastp.nf'
include { SHOVILL }              from '../../modules/assembly/shovill.nf'
include { QUAST }                from '../../modules/assembly/quast_iln.nf'
include { BAKTA }                from '../../modules/typing/bakta.nf'
include { RMLST }                from '../../modules/typing/rmlst.nf'
include { MLST }                 from '../../modules/typing/mlst.nf'
include { AMRFINDERPLUS }        from '../../modules/typing/amrfinderplus.nf'
include { PLASMIDFINDER }        from '../../modules/typing/plasmidfinder.nf'
include { RESULTS_PUBLISHER }    from '../../modules/utils/results_publisher.nf'

workflow ILN_PIPELINE {

    main:

        channel.fromPath(params.input_dir).view { input_path ->
            "input_dir = ${input_path}"
        }

        // --- Input Logic ---
        def normalized_out = NORMALIZE_SHORTREADS(file(params.input_dir))
        def fastp_in_ch = normalized_out.samples_tsv.map { tsv_file ->
            file(tsv_file).parent
        }

        // --- QC ---
        def fastp_out = FASTP(fastp_in_ch, params.fastp)

        def hq_reads = fastp_out.filtered
            .flatten()
            .map { filtered_file ->
                def base_name = file(filtered_file.baseName).baseName
                def sample_id = base_name.replace('_R1.hq', '').replace('_R2.hq', '').trim()
                return tuple(sample_id, filtered_file)
            }
            .groupTuple()
            .map { sample_id, file_list ->
                def read1 = file_list.find { fq -> fq.name.contains('_R1.hq.fastq.gz') }
                def read2 = file_list.find { fq -> fq.name.contains('_R2.hq.fastq.gz') }
                tuple(sample_id, read1, read2)
            }

        hq_reads.view { sample_id, read1, read2 ->
            "HQ Reads for SHOVILL - Sample_ID: ${sample_id}, R1: ${read1?.name}, R2: ${read2?.name}"
        }

        // --- Assembly ---
        def shovill_out = SHOVILL(hq_reads, params.shovill)
        def final_assembly = shovill_out.fasta

        final_assembly.view { sample_id, assembly_file ->
            "Shovill Assembly - Sample_ID: ${sample_id}, File: ${assembly_file.name}, Exists: ${assembly_file.exists()}"
        }

        // --- Analysis Tools ---
        def quast_in = hq_reads.join(final_assembly).map { sample_id, read1, read2, assembly_file ->
            tuple(sample_id, read1, read2, assembly_file)
        }
        def quast_out = QUAST(quast_in, params.quast)

        def bakta_in = final_assembly.map { sample_id, assembly_file ->
            tuple(sample_id, assembly_file)
        }
        def bakta_out = BAKTA(bakta_in, params.bakta)

        def rmlst_in = final_assembly.map { sample_id, assembly_file ->
            tuple(sample_id, assembly_file)
        }
        def rmlst_out = RMLST(rmlst_in)

        def mlst_in = final_assembly.map { sample_id, assembly_file ->
            tuple(sample_id, assembly_file)
        }
        def mlst_out = MLST(mlst_in, params.mlst)

        def amrfinder_in = final_assembly.join(rmlst_out.species).map { sample_id, assembly_file, species_file ->
            tuple(sample_id, assembly_file, species_file)
        }
        def amrfinder_out = AMRFINDERPLUS(amrfinder_in, params.amrfinder)

        def plasmidfinder_in = final_assembly.map { sample_id, assembly_file ->
            tuple(sample_id, assembly_file, params.db_root)
        }
        def plasmidfinder_out = PLASMIDFINDER(plasmidfinder_in, params.plasmidfinder)

        // --- Results ---
        def results_in = channel.empty()
            .mix(final_assembly.map          { sample_id, assembly_file -> tuple(sample_id, assembly_file, 'Fasta', params.mode) })
            .mix(amrfinder_out.txt.map       { sample_id, amr_file -> tuple(sample_id, amr_file, 'AMRFinderPlus', params.mode) })
            .mix(mlst_out.tsv.map            { sample_id, mlst_file -> tuple(sample_id, mlst_file, 'MLST', params.mode) })
            .mix(plasmidfinder_out.tsv.map   { sample_id, tsv_file -> tuple(sample_id, tsv_file, 'PlasmidFinder', params.mode) })
            .mix(quast_out.txt.map           {  sample_id, metrics_file -> tuple(sample_id, metrics_file, 'QUAST', params.mode) })
            .mix(bakta_out.tsv.map           { sample_id, tsv_file -> tuple(sample_id, tsv_file, 'Bakta', params.mode) })
            .mix(bakta_out.faa.map           { sample_id, faa_file -> tuple(sample_id, faa_file, 'Bakta', params.mode) })
            .mix(bakta_out.gbff.map          { sample_id, gbff_file -> tuple(sample_id, gbff_file, 'Bakta', params.mode) })
            .mix(rmlst_out.tsv.map           { sample_id, tsv_file -> tuple(sample_id, tsv_file, 'rMLST', params.mode) })

        def results_out = RESULTS_PUBLISHER(results_in)

    emit:
        filtered_reads  = hq_reads
        assembly        = final_assembly
        annotation      = bakta_out
        MLST            = mlst_out.tsv
        metrics         = quast_out.tsv
        amrfinderplus   = amrfinder_out.txt
        plasmidfinder   = plasmidfinder_out
        published_files = results_out
}