#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// ----------------------
// Modules
// ----------------------

include { NORMALIZE_SHORTREADS } from '../../modules/utils/normalization.nf'
include { FASTP }                from '../../modules/qc/fastp.nf'
include { SHOVILL }              from '../../modules/assembly/shovill.nf'
include { QUAST_ILN }            from '../../modules/assembly/quast_iln.nf'

include { BAKTA }                from '../../modules/typing/bakta.nf'
include { RMLST }                from '../../modules/typing/rmlst.nf'
include { MLST }                 from '../../modules/typing/mlst.nf'
include { AMRFINDERPLUS }        from '../../modules/typing/amrfinderplus.nf'
include { VIRULENCEFINDER }      from '../../modules/typing/virulencefinder.nf'

include { PLASMIDFINDER }        from '../../modules/plasmid/plasmidfinder.nf'
include { MOBTYPER }             from '../../modules/plasmid/mob_typer.nf'

include { RESULTS_PUBLISHER }    from '../../modules/utils/results_publisher.nf'

workflow ILN_PIPELINE {

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
    // Input Logic (Short Reads Only)
    // ============================================================

    channel.fromPath(params.input_dir).view { "input_dir = ${it}" }

    def normalized_out = NORMALIZE_SHORTREADS(file(params.input_dir))
    
    def fastp_input = normalized_out.tsv
        .map { file(it).parent }
        .unique()
    
    def fastp_out = FASTP(fastp_input, params.fastp)

    def hq_reads = fastp_out.filtered
        .flatten()
        .map { filtered_file ->
            def base_name = file(filtered_file.baseName).baseName
            def sample_id = base_name.replace('_R1.hq', '').replace('_R2.hq', '').trim()
            tuple(sample_id, filtered_file)
        }
        .groupTuple()
        .map { sample_id, file_list ->
            def read1 = file_list.find { it.name.contains('_R1.hq.fastq.gz') }
            def read2 = file_list.find { it.name.contains('_R2.hq.fastq.gz') }
            tuple(sample_id, read1, read2)
        }

    // ============================================================
    // Assembly (Shovill)
    // ============================================================

    def shovill_out = SHOVILL(hq_reads, params.shovill)
    def final_assembly = shovill_out.fasta

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
    def quast_out = QUAST_ILN(hq_reads.join(final_assembly), params.quast)
    
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

    // Capture Shovill log as assembly info
    def assembly_info_file = shovill_out.log

    // ============================================================
    // Results
    // ============================================================

    def results_in = channel.empty()
        .mix(final_assembly.map          { id, file -> tuple(id, file, 'Fasta', params.mode) })
        .mix(amrfinder_out.txt.map       { id, file -> tuple(id, file, 'AMRFinderPlus', params.mode) })
        .mix(mlst_out.tsv.map            { id, file -> tuple(id, file, 'MLST', params.mode) })
        .mix(rmlst_out.tsv.map           { id, file -> tuple(id, file, 'rMLST', params.mode) })
        .mix(quast_out.tsv.map           { id, file -> tuple(id, file, 'QUAST', params.mode) })
        .mix(plasmidfinder_out.tsv.map   { id, file -> tuple(id, file, 'PlasmidFinder', params.mode) })
        .mix(mob_out.tsv.map             { id, file -> tuple(id, file, 'MOBTyper', params.mode) })
        .mix(virulencefinder_out.tsv.map { id, file -> tuple(id, file, 'VirulenceFinder', params.mode) })
        .mix(bakta_out.tsv.map           { id, file -> tuple(id, file, 'Bakta', params.mode) })
        .mix(bakta_out.faa.map           { id, file -> tuple(id, file, 'Bakta', params.mode) })
        .mix(bakta_out.gbff.map          { id, file -> tuple(id, file, 'Bakta', params.mode) })
        .mix(assembly_info_file.map      { id, file -> tuple(id, file, 'AssemblyMetrics', params.mode) })

    def results_out = RESULTS_PUBLISHER(results_in)

    emit:
        filtered_reads             = hq_reads
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