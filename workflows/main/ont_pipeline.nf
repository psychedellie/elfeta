#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// -- Modules --
include { MERGE_FASTQS }        from '../../modules/utils/merge_fastqs.nf'
include { FASTPLONG }           from '../../modules/qc/fastplong.nf'
include { FLYE }                from '../../modules/assembly/flye.nf'
include { MEDAKA }              from '../../modules/assembly/medaka.nf'
include { QUAST }               from '../../modules/assembly/quast_ont.nf'
include { BAKTA }               from '../../modules/typing/bakta.nf'
include { RMLST }               from '../../modules/typing/rmlst.nf'
include { MLST }                from '../../modules/typing/mlst.nf'
include { AMRFINDERPLUS }       from '../../modules/typing/amrfinderplus.nf'
include { PLASMIDFINDER }       from '../../modules/typing/plasmidfinder.nf'
include { RESULTS_PUBLISHER }   from '../../modules/utils/results_publisher.nf'

workflow ONT_PIPELINE {

    main:

        // --- Input Logic ---
        channel.fromPath(params.input_dir).view { input_path ->
            "input_dir = ${input_path}"
        }

        def reads_ch

        if (file(params.input_dir).toFile().listFiles().find { current_file ->
            current_file.name.startsWith('barcode')
        }) {

            def merge_out_ch = MERGE_FASTQS(file(params.input_dir), file(params.sample_sheet)).out

            reads_ch = merge_out_ch
                .flatten()
                .map { merged_file ->
                    def combined_id = merged_file.name.replaceAll(/\.f(ast)?q(\.gz)?$/, '').trim()
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
            def representative_file = file(params.input_dir).toFile().listFiles().find { current_file ->
                current_file.name.endsWith('.fastq.gz')
            }

            if (!representative_file) {
                error "No .fastq.gz files found in input directory: ${params.input_dir}"
            }

            def combined_id = representative_file.name.replaceAll(/\.f(ast)?q(\.gz)?$/, '').trim()
            def sample_id = combined_id

            if (combined_id.contains('_')) {
                sample_id = combined_id.split('_')[-1]
            }

            println "Processing (Direct): Combined ID ${combined_id} -> Using Sample_ID ${sample_id}"
            reads_ch = channel.value(tuple(sample_id, file(params.input_dir)))
        }

        reads_ch.view { row ->
            "Final input - Sample_ID: ${row[0]}, Directory: ${row[1].name}"
        }

        // --- QC & Assembly ---
        def fastplong_out = FASTPLONG(reads_ch.map { row -> row[1] }.unique(), params.fastplong)

        def hq_reads = fastplong_out.filtered
            .flatten()
            .map { hq_file ->
                def base_name = hq_file.name.replaceAll(/\.hq\.f(ast)?q(\.gz)?$/, '').trim()
                def combined_id = base_name
                def sample_id = combined_id

                if (combined_id.contains('_')) {
                    sample_id = combined_id.split('_')[-1]
                }

                println "HQ Reads: Combined ID ${combined_id} -> Using Sample_ID ${sample_id}"
                return tuple(sample_id, hq_file)
            }

        hq_reads.view { row ->
            "HQ Reads for FLYE - Sample_ID: ${row[0]}, File: ${row[1].name}"
        }

        def flye_out = FLYE(hq_reads, params.flye)

        def medaka_in = hq_reads.join(flye_out.fasta).map { sample_id, fastq_file, assembly_file ->
            tuple(sample_id, fastq_file, assembly_file)
        }

        def medaka_out = MEDAKA(medaka_in, params.medaka)
        def final_assembly = medaka_out.fasta

        // --- Analysis Tools ---
        def quast_in = hq_reads.join(final_assembly).map { sample_id, fastq_file, assembly_file ->
            tuple(sample_id, fastq_file, assembly_file)
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
            .mix(flye_out.txt.map              { sample_id, file -> tuple(sample_id, file, 'Fasta/assembly_info', params.mode) })
            .mix(final_assembly.map            { sample_id, file -> tuple(sample_id, file, 'Fasta', params.mode) })
            .mix(amrfinder_out.txt.map         { sample_id, file -> tuple(sample_id, file, 'AMRFinderPlus', params.mode) })
            .mix(mlst_out.tsv.map              { sample_id, file -> tuple(sample_id, file, 'MLST', params.mode) })
            .mix(plasmidfinder_out.tsv.map     { sample_id, file -> tuple(sample_id, file, 'PlasmidFinder', params.mode) })
            .mix(quast_out.tsv.map             { sample_id, file -> tuple(sample_id, file, 'QUAST', params.mode) })
            .mix(bakta_out.tsv.map             { sample_id, file -> tuple(sample_id, file, 'Bakta', params.mode) })
            .mix(bakta_out.faa.map             { sample_id, file -> tuple(sample_id, file, 'Bakta', params.mode) })
            .mix(bakta_out.gbff.map            { sample_id, file -> tuple(sample_id, file, 'Bakta', params.mode) })
            .mix(rmlst_out.tsv.map             { sample_id, file -> tuple(sample_id, file, 'rMLST', params.mode) })

        def results_out = RESULTS_PUBLISHER(results_in)

    emit:
        filtered_reads     = hq_reads
        assembly           = final_assembly
        annotation         = bakta_out.outdir
        MLST               = mlst_out.tsv
        metrics            = quast_out.tsv
        amrfinderplus      = amrfinder_out.txt
        plasmidfinder      = plasmidfinder_out.outdir
        Published_Results  = results_out

}