#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// ----------------------
// Modules
// ----------------------

include { NORMALIZE_SHORTREADS } from '../../modules/utils/normalization.nf'
include { MERGE_FASTQS }         from '../../modules/utils/merge_fastqs.nf'
include { FASTP }                from '../../modules/qc/fastp.nf'
include { FASTPLONG }            from '../../modules/qc/fastplong.nf'
include { FLYE }                 from '../../modules/assembly/flye.nf'
include { MEDAKA }               from '../../modules/assembly/medaka.nf'
include { BWA_INDEX }            from '../../modules/assembly/bwa_index.nf'
include { BWA_MEM }              from '../../modules/assembly/bwa_mem.nf'
include { POLYPOLISH_FILTER }    from '../../modules/assembly/polypolish_filter.nf'
include { POLYPOLISH_POLISH }    from '../../modules/assembly/polypolish_polish.nf'
include { QUAST_ONT }            from '../../modules/assembly/quast_ont.nf'

include { BAKTA }                from '../../modules/typing/bakta.nf'
include { RMLST }                from '../../modules/typing/rmlst.nf'
include { MLST }                 from '../../modules/typing/mlst.nf'
include { AMRFINDERPLUS }        from '../../modules/typing/amrfinderplus.nf'
include { VIRULENCEFINDER }      from '../../modules/typing/virulencefinder.nf'

include { PLASMIDFINDER }        from '../../modules/plasmid/plasmidfinder.nf'
include { MOBTYPER }             from '../../modules/plasmid/mob_typer.nf'

include { RESULTS_PUBLISHER }    from '../../modules/utils/results_publisher.nf'

workflow SP_PIPELINE {

    main:

    // ----------------------
    // Placeholders
    // ----------------------

    def bakta_out_empty = [
        tsv:    channel.empty(),
        faa:    channel.empty(),
        gbff:   channel.empty(),
        outdir: channel.empty()
    ]

    def virulencefinder_out_empty = [
        outdir: channel.empty(),
        tsv:    channel.empty(),
        status: channel.empty()
    ]

    // ============================================================
    // Input Logic (Short & Long Reads)
    // ============================================================

    channel.fromPath(params.input_dir).view { "input_dir = ${it}" }

    // Short Read Pre-processing
    def normalization_out = NORMALIZE_SHORTREADS(file(params.input_dir))
    def fastp_input = normalization_out.tsv.map { file(it).parent }
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
            def read1 = fastq_files.find { it.name.contains('_R1.hq.fastq.gz') }
            def read2 = fastq_files.find { it.name.contains('_R2.hq.fastq.gz') }
            tuple(sample_id, read1, read2)
        }

    // Long Read Input detection
    def reads_channel
    if (file(params.input_dir).toFile().listFiles().find { it.name.startsWith('barcode') }) {
        def merge_output = MERGE_FASTQS(file(params.input_dir), file(params.sample_sheet)).out
        reads_channel = merge_output
            .flatten()
            .map { merged_file ->
                def combined_id = merged_file.name.replaceAll(/\.f(ast)?q(\.gz)?$/, '').trim()
                def sample_id = combined_id.contains('_') ? combined_id.split('_')[-1] : combined_id
                tuple(sample_id, file(merged_file.getParent()))
            }
    } else {
        def representative_file = file(params.input_dir).toFile().listFiles().find { it.name.endsWith('.fastq.gz') }
        if (!representative_file) error "No .fastq.gz files found in input directory: ${params.input_dir}"
        
        def combined_id = representative_file.name.replaceAll(/\.f(ast)?q(\.gz)?$/, '').trim()
        def sample_id = combined_id.contains('_') ? combined_id.split('_')[-1] : combined_id
        reads_channel = channel.value(tuple(sample_id, file(params.input_dir)))
    }

    // ============================================================
    // QC & Hybrid Assembly
    // ============================================================

    def fastplong_out = FASTPLONG(reads_channel.map { it[1] }.unique(), params.fastplong)

    def hq_reads_ont = fastplong_out.filtered
        .flatten()
        .filter { !it.name.contains('_R1.hq') && !it.name.contains('_R2.hq') }
        .map { fastq_file ->
            def base_name = fastq_file.name.replaceAll(/\.hq\.f(ast)?q(\.gz)?$/, '').trim()
            def sample_id = base_name.contains('_') ? base_name.split('_')[-1] : base_name
            tuple(sample_id, fastq_file)
        }

    // Assembly & Medaka
    def flye_out = FLYE(hq_reads_ont, params.flye)
    def medaka_in = hq_reads_ont.join(flye_out.fasta)
    def medaka_out = MEDAKA(medaka_in, params.medaka)

    // Polypolish (Hybrid Polishing)
    def bwa_index_out = BWA_INDEX(medaka_out.fasta, params.bwa_idx)
    def bwa_mem_in = bwa_index_out.idx.join(hq_reads_iln).map { sample_id, cons, idx_dir, r1, r2 ->
        tuple(sample_id, file("${idx_dir}/${sample_id}"), r1, r2)
    }
    def bwa_mem_out = BWA_MEM(bwa_mem_in, params.bwa_mem)
    def filter_out = POLYPOLISH_FILTER(bwa_mem_out.sam1.join(bwa_mem_out.sam2), params.polypolish_filter)
    
    def final_assembly = POLYPOLISH_POLISH(
        medaka_out.fasta.join(filter_out.sams), 
        params.polypolish_polish
    ).fasta

    // ============================================================
    // Analysis Tools
    // ============================================================

    // Plasmid Analysis
    def mob_out = MOBTYPER(final_assembly, params.mobtyper)
    def plasmidfinder_out = PLASMIDFINDER(
        final_assembly.map { id, fa -> tuple(id, fa, params.db_root) }, 
        params.plasmidfinder
    )

    // Typing & Annotation
    def quast_out = QUAST_ONT(hq_reads_ont.join(final_assembly), params.quast)
    
    def bakta_out = params.skip_bakta ? bakta_out_empty : BAKTA(final_assembly, params.bakta)
    
    def rmlst_out = RMLST(final_assembly)
    def mlst_out = MLST(final_assembly, params.mlst)
    
    def amrfinder_out = AMRFINDERPLUS(
        final_assembly.join(rmlst_out.species), 
        params.amrfinder
    )

    def virulencefinder_out = params.skip_virulencefinder ? virulencefinder_out_empty : VIRULENCEFINDER(
        final_assembly.join(rmlst_out.tsv).map { id, fa, rtsv -> tuple(id, fa, rtsv, params.db_root) },
        params.virulencefinder
    )

    def assembly_info_file = flye_out.txt

    // ============================================================
    // Results
    // ============================================================

    def results_in = channel.empty()
        .mix(final_assembly.map        { id, file -> tuple(id, file, 'Fasta', params.mode) })
        .mix(amrfinder_out.txt.map     { id, file -> tuple(id, file, 'AMRFinderPlus', params.mode) })
        .mix(mlst_out.tsv.map          { id, file -> tuple(id, file, 'MLST', params.mode) })
        .mix(rmlst_out.tsv.map         { id, file -> tuple(id, file, 'rMLST', params.mode) })
        .mix(quast_out.tsv.map         { id, file -> tuple(id, file, 'QUAST', params.mode) })
        .mix(plasmidfinder_out.tsv.map { id, file -> tuple(id, file, 'PlasmidFinder', params.mode) })
        .mix(mob_out.tsv.map           { id, file -> tuple(id, file, 'MOBTyper', params.mode) })
        .mix(virulencefinder_out.tsv.map { id, file -> tuple(id, file, 'VirulenceFinder', params.mode) })
        .mix(bakta_out.tsv.map         { id, file -> tuple(id, file, 'Bakta', params.mode) })
        .mix(bakta_out.faa.map         { id, file -> tuple(id, file, 'Bakta', params.mode) })
        .mix(bakta_out.gbff.map        { id, file -> tuple(id, file, 'Bakta', params.mode) })
        .mix(assembly_info_file.map    { id, file -> tuple(id, file, 'AssemblyMetrics', params.mode) })

    def results_out = RESULTS_PUBLISHER(results_in)

    emit:
        Filtered_ONT_reads         = hq_reads_ont
        Filtered_ILN_reads         = hq_reads_iln
        Final_Assembly             = final_assembly
        Gene_Annotation            = bakta_out.outdir
        Sequence_Typing            = mlst_out.tsv
        Sequencing_Metrics         = quast_out.tsv
        ARGs_PMs_VGs               = amrfinder_out.txt
        Plasmid_Profiles           = plasmidfinder_out.outdir
        MOB_Profiles               = mob_out.tsv
        VirulenceFinder_Profiles   = virulencefinder_out.outdir
        Published_Results          = results_out
        Assembly_Info_Files        = assembly_info_file
}