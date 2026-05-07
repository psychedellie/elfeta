#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// ----------------------
// Modules
// ----------------------

include { MERGE_FASTQS }      from '../../modules/utils/merge_fastqs.nf'
include { FASTPLONG }         from '../../modules/qc/fastplong.nf'
include { FLYE }              from '../../modules/assembly/flye.nf'
include { MEDAKA }            from '../../modules/assembly/medaka.nf'
include { QUAST_ONT }         from '../../modules/assembly/quast_ont.nf'

include { BAKTA }             from '../../modules/typing/bakta.nf'
include { RMLST }             from '../../modules/typing/rmlst.nf'
include { MLST }              from '../../modules/typing/mlst.nf'
include { AMRFINDERPLUS }     from '../../modules/typing/amrfinderplus.nf'

include { PLASMIDFINDER }     from '../../modules/plasmid/plasmidfinder.nf'
include { MOBTYPER }          from '../../modules/plasmid/mob_typer.nf'
include { VIRULENCEFINDER }   from '../../modules/typing/virulencefinder.nf'

include { RESULTS_PUBLISHER } from '../../modules/utils/results_publisher.nf'


workflow ONT_PIPELINE {

    main:

    // ----------------------
    // BAKTA placeholder
    // ----------------------

    def bakta_out_empty = [
        tsv:    channel.empty(),
        faa:    channel.empty(),
        gbff:   channel.empty(),
        outdir: channel.empty()
    ]

    channel.fromPath(params.input_dir).view { input_path ->
        "input_dir = ${input_path}"
    }

    def reads_ch

    // ----------------------
    // Input detection
    // ----------------------

    if (file(params.input_dir).toFile().listFiles().find { current_file ->
        current_file.name.startsWith('barcode')
    }) {

        def merge_out_ch = MERGE_FASTQS(
            file(params.input_dir),
            file(params.sample_sheet)
        ).out

        reads_ch = merge_out_ch
            .flatten()
            .map { merged_file ->

                def combined_id = merged_file.name
                    .replaceAll(/\.f(ast)?q(\.gz)?$/, '')
                    .trim()

                def sample_id = combined_id.contains('_')
                    ? combined_id.split('_')[-1]
                    : combined_id

                def merged_dir = merged_file.getParent()

                tuple(sample_id, file(merged_dir))
            }

    } else {

        def representative_file = file(params.input_dir)
            .toFile()
            .listFiles()
            .find { current_file ->
                current_file.name.endsWith('.fastq.gz')
            }

        if (!representative_file) {
            error "No .fastq.gz files found in input directory: ${params.input_dir}"
        }

        def combined_id = representative_file.name
            .replaceAll(/\.f(ast)?q(\.gz)?$/, '')
            .trim()

        def sample_id = combined_id.contains('_')
            ? combined_id.split('_')[-1]
            : combined_id

        reads_ch = channel.value(tuple(sample_id, file(params.input_dir)))
    }


    // ============================================================
    // QC & Assembly
    // ============================================================

    def fastplong_out = FASTPLONG(
        reads_ch.map { row -> row[1] }.unique(),
        params.fastplong
    )

    def hq_reads = fastplong_out.filtered
        .flatten()
        .map { hq_file ->

            def base_name = hq_file.name
                .replaceAll(/\.hq\.f(ast)?q(\.gz)?$/, '')
                .trim()

            def sample_id = base_name.contains('_')
                ? base_name.split('_')[-1]
                : base_name

            tuple(sample_id, hq_file)
        }

    def flye_out = FLYE(hq_reads, params.flye)

    def medaka_in = hq_reads.join(flye_out.fasta)
        .map { sample_id, fastq_file, assembly_file ->
            tuple(sample_id, fastq_file, assembly_file)
        }

    def medaka_out = MEDAKA(medaka_in, params.medaka)

    def final_assembly = medaka_out.fasta


    // ============================================================
    // PLASMID ANALYSIS
    // ============================================================

    def mob_out = MOBTYPER(
        final_assembly.map { sample_id, fasta_file ->
            tuple(sample_id, fasta_file)
        },
        params.mobtyper
    )

    def plasmidfinder_out = PLASMIDFINDER(
        final_assembly.map { sample_id, fasta_file ->
            tuple(sample_id, fasta_file, params.db_root)
        },
        params.plasmidfinder
    )


    // ============================================================
    // CORE ANALYSIS
    // ============================================================

    def quast_out = QUAST_ONT(
        hq_reads.join(final_assembly)
            .map { sample_id, fastq_file, assembly_file ->
                tuple(sample_id, fastq_file, assembly_file)
            },
        params.quast
    )

    def bakta_out

    if (!params.skip_bakta) {
        bakta_out = BAKTA(final_assembly, params.bakta)
    } else {
        bakta_out = bakta_out_empty
    }

    def rmlst_out = RMLST(final_assembly)

    def mlst_out = MLST(final_assembly, params.mlst)

    def amrfinder_out = AMRFINDERPLUS(
        final_assembly.join(rmlst_out.species)
            .map { sample_id, assembly_file, species_file ->
                tuple(sample_id, assembly_file, species_file)
            },
        params.amrfinderplus
    )

    def virulencefinder_out

    if (!params.skip_virulencefinder) {
        virulencefinder_out = VIRULENCEFINDER(
            final_assembly
                .join(rmlst_out.tsv)
                .map { sample_id, assembly_file, rmlst_tsv ->
                    tuple(sample_id, assembly_file, rmlst_tsv, params.db_root)
                },
            params.virulencefinder
        )
    } else {
        virulencefinder_out = [
            outdir: channel.empty(),
            tsv:    channel.empty(),
            status: channel.empty()
        ]
    }

    def assembly_info_file = flye_out.txt
        .map { sample_id, assembly_info ->
            tuple(sample_id, assembly_info)
        }


    // ============================================================
    // RESULTS
    // ============================================================

    def results_in = channel.empty()

        .mix(final_assembly.map { sample_id, file ->
            tuple(sample_id, file, 'Fasta', params.mode)
        })

        .mix(amrfinder_out.txt.map { sample_id, file ->
            tuple(sample_id, file, 'AMRFinderPlus', params.mode)
        })

        .mix(mlst_out.tsv.map { sample_id, file ->
            tuple(sample_id, file, 'MLST', params.mode)
        })

        .mix(rmlst_out.tsv.map { sample_id, file ->
            tuple(sample_id, file, 'rMLST', params.mode)
        })

        .mix(quast_out.tsv.map { sample_id, file ->
            tuple(sample_id, file, 'QUAST', params.mode)
        })

        .mix(plasmidfinder_out.tsv.map { sample_id, file ->
            tuple(sample_id, file, 'PlasmidFinder', params.mode)
        })

        .mix(mob_out.tsv.map { sample_id, file ->
            tuple(sample_id, file, 'MOBTyper', params.mode)
        })

        .mix(virulencefinder_out.tsv.map { sample_id, file ->
            tuple(sample_id, file, 'VirulenceFinder', params.mode)
        })

        .mix(bakta_out.tsv.map { sample_id, file ->
            tuple(sample_id, file, 'Bakta', params.mode)
        })

        .mix(bakta_out.faa.map { sample_id, file ->
            tuple(sample_id, file, 'Bakta', params.mode)
        })

        .mix(bakta_out.gbff.map { sample_id, file ->
            tuple(sample_id, file, 'Bakta', params.mode)
        })

        .mix(assembly_info_file.map { sample_id, file ->
            tuple(sample_id, file, 'AssemblyMetrics', params.mode)
        })


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
        VirulenceFinder_TSV        = virulencefinder_out.tsv
        Published_Results          = results_out
        Assembly_Info_Files        = assembly_info_file
}