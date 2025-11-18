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
include { POLYPOLISH_FILTER}     from '../modules/assembly/polypolish_filter.nf'
include { POLYPOLISH_POLISH }    from '../modules/assembly/polypolish_polish.nf'
include { QUAST }                from '../modules/assembly/quast_ont.nf'
include { BAKTA }                from '../modules/typing/bakta.nf'
include { RMLST }                from '../modules/typing/rmlst.nf'
include { MLST }                 from '../modules/typing/mlst.nf'
include { AMRFINDERPLUS }        from '../modules/typing/amrfinderplus.nf'
include { PLASMIDFINDER }        from '../modules/typing/plasmidfinder.nf'
include { RESULTS_PUBLISHER }    from '../modules/utils/results_publisher.nf'

workflow HBD_PIPELINE {

    main:
        channel
            .fromPath(params.input_dir)
            .view { input_path -> "Input directory: ${input_path}" }

        def normalization_out = NORMALIZE_SHORTREADS(file(params.input_dir))

        def fastp_out = FASTP(
            normalization_out.samples_tsv.map { tsv_path -> 
                file(tsv_path).parent 
            }
        )

        def hq_reads_iln = fastp_out.filtered
            .flatten()
            .map { fastq_path ->
                def base_name = file(fastq_path.baseName).baseName
                def sample_id = base_name
                    .replace('_R1.hq', '')
                    .replace('_R2.hq', '')
                    .trim()
                tuple(sample_id, fastq_path)
            }
            .groupTuple()
            .map { sample_id, fastq_files ->
                def r1_file = fastq_files.find { candidate -> candidate.name.contains('_R1.hq.fastq.gz') }
                def r2_file = fastq_files.find { candidate -> candidate.name.contains('_R2.hq.fastq.gz') }
                tuple(sample_id, r1_file, r2_file)
            }

        hq_reads_iln.view { sample_id, r1_file, r2_file ->
            "HQ reads (short) -> ${sample_id} | R1=${r1_file?.name} | R2=${r2_file?.name}"
        }

        def reads_channel

        def has_barcodes = file(params.input_dir)
            .toFile()
            .listFiles()
            .find { entry -> entry.name.startsWith('barcode') }

        if (has_barcodes) {

            def merge_out = MERGE_FASTQS(file(params.input_dir), file(params.sample_sheet)).out

            reads_channel = merge_out
                .flatten()
                .map { merged_fastq ->
                    def base_name = file(merged_fastq.baseName).baseName
                    def sample_id = base_name.contains('_') ? base_name.split('_')[-1] : base_name
                    def parent_dir = merged_fastq.parent
                    println "Merging barcoded reads: ${base_name} -> ${sample_id}"
                    tuple(sample_id, file(parent_dir))
                }

        } else {

            def representative = file(params.input_dir)
                .toFile()
                .listFiles()
                .find { entry -> entry.name.endsWith('.fastq.gz') }

            if (!representative) {
                error "No .fastq.gz files found in ${params.input_dir}"
            }

            def base_name = file(representative.baseName).baseName
            def sample_id = base_name.contains('_') ? base_name.split('_')[-1] : base_name
            println "Processing direct reads: ${base_name} -> ${sample_id}"

            reads_channel = channel.value(tuple(sample_id, file(params.input_dir)))
        }

        reads_channel.view { sample_id, directory_path ->
            "Final reads input -> ${sample_id} | Directory=${directory_path.name}"
        }

        def fastplong_out = FASTPLONG(reads_channel.map { row -> row[1] }.unique())

        def hq_reads_ont = fastplong_out.filtered
            .flatten()
            .filter { fastq_path ->
                !fastq_path.name.contains('_R1.hq') && !fastq_path.name.contains('_R2.hq')
            }
            .map { fastq_path ->
                def base_name = file(fastq_path.baseName).baseName
                def sample_id = base_name.replace('.hq', '').split('_')[-1].trim()
                tuple(sample_id, fastq_path)
            }

        hq_reads_ont.view { sample_id, fastq_path ->
            "HQ reads (long) -> ${sample_id} | File=${fastq_path.name}"
        }

        def flye_out = FLYE(hq_reads_ont)

        def medaka_in = hq_reads_ont
            .join(flye_out.assembly)
            .map { sample_id, long_fastq, flye_assembly ->
                tuple(sample_id, long_fastq, flye_assembly, params.basecaller)
            }

        MEDAKA(medaka_in)

        def bwa_index_out = BWA_INDEX(MEDAKA.out.consensus)

        def bwa_mem_in = bwa_index_out.index
            .join(hq_reads_iln)
            .map { sample_id, _consensus_fasta, index_dir, r1_file, r2_file ->
        def index_prefix = file("${index_dir}/${sample_id}")
        tuple(sample_id, index_prefix, r1_file, r2_file)
                }
        bwa_mem_in.view { sample_id, prefix, r1, r2 ->
            "BWA_MEM INPUT -> sample_id: ${sample_id} | prefix: ${prefix} | r1: ${r1.name} | r2: ${r2.name}"
            }

        def bwa_mem_out = BWA_MEM(bwa_mem_in)

        def polypolish_filter_in = bwa_mem_out.sam1.join(bwa_mem_out.sam2)

        def filter_out = POLYPOLISH_FILTER(polypolish_filter_in)

        def polypolish_in = MEDAKA.out.consensus
            .join(filter_out.filtered_sams)
            .map { sample_id, assembly_fasta, filtered_1_sam, filtered_2_sam ->
                tuple(sample_id, assembly_fasta, filtered_1_sam, filtered_2_sam, params.polypolish_args)
            }

        POLYPOLISH_POLISH(polypolish_in)

        def final_assembly = POLYPOLISH_POLISH.out.assembly

        final_assembly.view { sample_id, assembly_file ->
            "Hybrid Assembly Complete -> ${sample_id} | ${assembly_file.name}"
        }

        def quast_in = hq_reads_ont
            .join(final_assembly)
            .map { sample_id, long_fastq, consensus_file ->
                return tuple( sample_id, long_fastq, consensus_file )
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
            .mix(PLASMIDFINDER.out.tsv.map { sid, f -> tuple(sid, f, 'PlasmidFinder', params.mode) })
            .mix(QUAST.out.metrics.map { sid, f -> tuple(sid, f, 'QUAST', params.mode) })
            .mix(BAKTA.out.tsv.map { sid, f -> tuple(sid, f, 'Bakta', params.mode)})
            .mix(BAKTA.out.faa.map { sid, f -> tuple(sid, f, 'Bakta', params.mode) })
            .mix(BAKTA.out.gbff.map { sid, f -> tuple(sid, f, 'Bakta', params.mode) })
            .mix(RMLST.out.tsv.map { sid, f -> tuple(sid, f, 'rMLST', params.mode) })

        RESULTS_PUBLISHER(results_in)
    //----------------------------------------------------------------------
    // 7. Workflow outputs
    //----------------------------------------------------------------------
    emit:
        filtered_ont_reads = hq_reads_ont
        filtered_iln_reads = hq_reads_iln
        assembly           = final_assembly
        annotation         = BAKTA.out.annot
        MLST               = MLST.out.mlst
        metrics            = QUAST.out.metrics
        amrfinderplus      = AMRFINDERPLUS.out.amrf
        plasmidfinder      = PLASMIDFINDER.out.plasmid
        published_files    = RESULTS_PUBLISHER.out.published_file
}