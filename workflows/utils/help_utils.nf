def SHOW_HELP () {
    log.info """
    ONT / Illumina / Short-Read Polishing / Long-Read Polishing Assembly & Polishing Pipeline — Help Menu
    ------------------------------------------------------------
    
    Description:
      This pipeline supports hybrid workflows for genome assembly and polishing using ONT, Illumina, 
      short-read polishing, or long-read polishing data. Parameters are organized into required, 
      optional, database setup, and tool-specific categories for clarity.

    ------------------------------------------------------------
    Required parameters (for main analysis):
      --mode                  Sequencing mode. Accepted values: 'ont', 'iln', 'sr', or 'lr'
      --input_dir, -i         Path to directory containing input FASTQ files
      --sample_sheet, -s      Path to CSV sample sheet describing samples and reads
      --output_dir, -o        Path to output directory for all generated results
      --db_root, -d           Path to local database root directory. Required for both analysis and database setup

    Optional parameters:
      --enable_gpu            Enable GPU acceleration for compatible tools (default: false)
      --useMamba              Use Micromamba for environment management (default: false)
      --max_cpus, -c          Maximum number of CPUs to use (default: 8)
      --max_memory, -m        Maximum memory allocation (default: 16 GB)
      --db_setup              Run only the database setup and configuration process
      --help, -h              Display this help menu and exit

    Database setup parameters (used only with --db_setup):
      --db_root, -d           Path to local database root directory (required)
      --bakta_db_type         Bakta database type ('light' or 'full', default: light)
      --force_db_update       Force update of local database files (default: empty)

    Tool-specific parameters (optional):
      --fastp                 Options passed to Fastp
      --fastplong             Options passed to Fastp Long
      --shovill               Options passed to Shovill
      --flye                  Options passed to Flye
      --unicycler             Options passed to Unicycler
      --medaka                Options passed to Medaka
      --bwa_idx               Options passed to BWA index
      --bwa_mem               Options passed to BWA MEM
      --polypolish_filter     Options passed to Polypolish Filter
      --polypolish_polish     Options passed to Polypolish Polish
      --quast                 Options passed to QUAST
      --mlst                  Options passed to MLST
      --bakta                 Options passed to Bakta
      --amrfinderplus         Options passed to AMRFinderPlus
      --plasmidfinder         Options passed to PlasmidFinder (default: --extented_output)

    Internal paths:
      --results_dir           Result directory path (default: <output_dir>/Results)
      --scripts_dir           Path to workflow scripts (default: <projectDir>/scripts)
      --envs_dir              Path to environment definitions (default: <projectDir>/envs)

    Example run:
      nextflow run main.nf \\
        --mode ont \\
        --i fastq_dir \\
        --s sample_sheet.csv \\
        --o analysis \\
        --d database_dir \\
        --c 16 \\
        --m 32G \\
        --enable_gpu true \\
        --useMamba true \\
        -profile laptop

    Example database setup only:
      nextflow run main.nf \\
        --db_setup \\
        --d database_dir \\
        --bakta_db_type full \\
        --force_db_update true

    ------------------------------------------------------------
    """
    System.exit(0)
}
