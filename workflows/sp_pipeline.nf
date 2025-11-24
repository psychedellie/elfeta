#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// -- Modules --
include { NORMALIZE_SHORTREADS } from '../modules/utils/normalization.nf'
include { MERGE_FASTQS }         from '../modules/utils/merge_fastqs.nf'
include { FASTP }                from '../modules/qc/fastp.nf'
include { FASTPLONG }            from '../modules/qc/fastplong.nf'
include { FLYE }                 from '../modules/assembly/flye.nf'
include { MEDAKA }               from '../modules/assembly/medaka.nf'
include { BWA_INDEX }            from '../modules/assembly/bwa_index.nf'
include { BWA_MEM }              from '../modules/assembly/bwa_mem.nf'
include { POLYPOLISH_FILTER }    from '../modules/assembly/polypolish_filter.nf'
include { POLYPOLISH_POLISH }    from '../modules/assembly/polypolish_polish.nf'
include { QUAST }                from '../modules/assembly/quast_ont.nf'
include { BAKTA }                from '../modules/typing/bakta.nf'
include { RMLST }                from '../modules/typing/rmlst.nf'
include { MLST }                 from '../modules/typing/mlst.nf'
include { AMRFINDERPLUS }        from '../modules/typing/amrfinderplus.nf'
include { PLASMIDFINDER }        from '../modules/typing/plasmidfinder.nf'
include { RESULTS_PUBLISHER }    from '../modules/utils/results_publisher.nf'

workflow SP_PIPELINE {

    main:

        // --- Input Logic ---
        channel.fromPath(params.input_dir).view { input_dir ->
            "input_dir = ${input_dir}"
        }

        def normalization_out = NORMALIZE_SHORTREADS(file(params.input_dir))

        def fastp_input = normalization_out.tsv.map { tsv_file ->
            file(tsv_file).parent
        }

        def fastp_out = FASTP(fastp_input, params.fastp)

        def hq_reads_iln = fastp_out.filtered
            .flatten()
            .map { fastq_file ->
                def base_name = file(fastq_file.baseName).baseName
                def sample_id = base_name.replace('_R1.hq', '').replace('_R2.hq', '').trim()
                tuple(sample_id, fastq_file)
            }
            .groupTuple()
            .map { sample_id, fastq_files ->
                def read1 = fastq_files.find { fq -> fq.name.contains('_R1.hq.fastq.gz') }
                def read2 = fastq_files.find { fq -> fq.name.contains('_R2.hq.fastq.gz') }
                tuple(sample_id, read1, read2)
            }

        hq_reads_iln.view { sample_id, read1, read2 ->
            "HQ Reads (short) - Sample_ID: ${sample_id}, R1: ${read1?.name}, R2: ${read2?.name}"
        }

        def reads_channel
        def barcode_check = file(params.input_dir).toFile().listFiles().find { current_file ->
            current_file.name.startsWith('barcode')
        }

        if (barcode_check) {
            def merge_output = MERGE_FASTQS(file(params.input_dir), file(params.sample_sheet)).out

            reads_channel = merge_output
                .flatten()
                .map { merged_file ->
                    def combined_name = merged_file.name.replaceAll(/\.f(ast)?q(\.gz)?$/, '').trim()
                    def sample_id = combined_name.contains('_') ? combined_name.split('_')[-1] : combined_name
                    def parent_dir = merged_file.getParent()
                    println "Merging barcoded reads: Combined ${combined_name} -> Sample_ID ${sample_id}"
                    return tuple(sample_id, file(parent_dir))
                }
        }
        else {
            def representative_file = file(params.input_dir).toFile().listFiles().find { current_file ->
                current_file.name.endsWith('.fastq.gz')
            }

            if (!representative_file) {
                error "No .fastq.gz files found in input directory: ${params.input_dir}"
            }

            def base_name = representative_file.name.replaceAll(/\.f(ast)?q(\.gz)?$/, '').trim()
            def sample_id = base_name.contains('_') ? base_name.split('_')[-1] : base_name
            println "Processing direct reads: Combined ${base_name} -> Sample_ID ${sample_id}"

            reads_channel = channel.value(tuple(sample_id, file(params.input_dir)))
        }

        reads_channel.view { sample_id, directory_path ->
            "Final input - Sample_ID: ${sample_id}, Directory: ${directory_path.name}"
        }

        // --- QC & Assembly (Long Reads) ---
        def fastplong_out = FASTPLONG(reads_channel.map { row -> row[1] }.unique(), params.fastplong)

        def hq_reads_ont = fastplong_out.filtered
            .flatten()
            .filter { fastq_file ->
                !fastq_file.name.contains('_R1.hq') && !fastq_file.name.contains('_R2.hq')
            }
            .map { fastq_file ->
                def base_name = fastq_file.name.replaceAll(/\.hq\.f(ast)?q(\.gz)?$/, '').trim()
                def sample_id = base_name.contains('_') ? base_name.split('_')[-1] : base_name
                tuple(sample_id, fastq_file)
            }

        hq_reads_ont.view { sample_id, fastq_file ->
            "HQ Reads (long) - Sample_ID: ${sample_id}, File: ${fastq_file.name}"
        }

        def flye_out = FLYE(hq_reads_ont, params.flye)
        def medaka_in = hq_reads_ont.join(flye_out.fasta).map { sample_id, long_fastq, assembly_file ->
            tuple(sample_id, long_fastq, assembly_file)
        }
        def medaka_out = MEDAKA(medaka_in, params.medaka)

        // --- Hybrid Polishing ---
        def bwa_index_out = BWA_INDEX(medaka_out.fasta, params.bwa_idx)
        def bwa_mem_in = bwa_index_out.idx.join(hq_reads_iln).map { sample_id, _consensus_file, index_dir, read1, read2 ->
            def index_prefix = file("${index_dir}/${sample_id}")
            tuple(sample_id, index_prefix, read1, read2)
        }

        bwa_mem_in.view { sample_id, prefix, read1, read2 ->
            "BWA_MEM Input - Sample_ID: ${sample_id}, Prefix: ${prefix}, R1: ${read1.name}, R2: ${read2.name}"
        }

        def bwa_mem_out = BWA_MEM(bwa_mem_in, params.bwa_mem)
        def polypolish_filter_in = bwa_mem_out.sam1.join(bwa_mem_out.sam2)
        def filter_out = POLYPOLISH_FILTER(polypolish_filter_in, params.polypolish_filter)

        def polypolish_in = medaka_out.fasta.join(filter_out.sams).map { sample_id, assembly_fasta, filtered_sam1, filtered_sam2 ->
            tuple(sample_id, assembly_fasta, filtered_sam1, filtered_sam2)
        }

        def polypolish_out = POLYPOLISH_POLISH(polypolish_in, params.polypolish_polish)
        def final_assembly = polypolish_out.fasta

        final_assembly.view { sample_id, assembly_file ->
            "Hybrid Assembly - Sample_ID: ${sample_id}, File: ${assembly_file.name}"
        }

        // --- Analysis Tools ---
        def quast_in = hq_reads_ont.join(final_assembly).map { sample_id, long_fastq, assembly_file ->
            tuple(sample_id, long_fastq, assembly_file)
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
            .mix(flye_out.txt.map            { sample_id, file -> tuple(sample_id, file, 'Fasta/assembly_info', params.mode) })
            .mix(final_assembly.map          { sample_id, file -> tuple(sample_id, file, 'Fasta', params.mode) })
            .mix(amrfinder_out.txt.map       { sample_id, file -> tuple(sample_id, file, 'AMRFinderPlus', params.mode) })
            .mix(mlst_out.tsv.map            { sample_id, file -> tuple(sample_id, file, 'MLST', params.mode) })
            .mix(plasmidfinder_out.tsv.map   { sample_id, file -> tuple(sample_id, file, 'PlasmidFinder', params.mode) })
            .mix(quast_out.tsv.map           { sample_id, file -> tuple(sample_id, file, 'QUAST', params.mode) })
            .mix(bakta_out.tsv.map           { sample_id, file -> tuple(sample_id, file, 'Bakta', params.mode) })
            .mix(bakta_out.faa.map           { sample_id, file -> tuple(sample_id, file, 'Bakta', params.mode) })
            .mix(bakta_out.gbff.map          { sample_id, file -> tuple(sample_id, file, 'Bakta', params.mode) })
            .mix(rmlst_out.tsv.map           { sample_id, file -> tuple(sample_id, file, 'rMLST', params.mode) })

        def results_out = RESULTS_PUBLISHER(results_in)

    emit:
        Filtered_ONT_reads    = hq_reads_ont
        Filtered_ILN_reads    = hq_reads_iln
        Final_Assembly        = final_assembly
        Gene_Annotation       = bakta_out.outdir
        Sequence_Typing       = mlst_out.tsv
        Sequencing_Metrics    = quast_out.tsv
        ARGs_PMs_VGs          = amrfinder_out.txt
        Plasmid_Profiles      = plasmidfinder_out.outdir
        Published_Results     = results_out
}