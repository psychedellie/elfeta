def showHelp() {
    log.info """
    ONT / Illumina Assembly & Polishing Pipeline — Help Menu
    ------------------------------------------------------------

    Required parameters:
      --mode                  Sequencing mode: 'ont' or 'iln'
      --input_dir, -i         Path to directory with input FASTQ files
      --sample_sheet, -s      Path to CSV sample sheet
      --output_dir, -o        Output directory for results
      --db_root, --d          Path to local database directory

    Optional parameters:
      --basecaller, --b       Basecaller model (ONT only, default: r1041_e82_400bps_sup_v5.2.0)
      --max_cpus, --c         Maximum number of CPUs (default: 8)
      --max_memory, --m       Maximum memory (default: 16 GB)
      --enable_gpu            Use GPU acceleration for compatible tools (default: false)

    Example:
      nextflow run main.nf \\
        --mode ont \\
        --i fastq_dir \\
        --s sample_sheet.csv \\
        --o analysis \\
        --d database_dir \\
        --b r1041_e82_400bps_sup_v5.0.0 \\
        --c 16
        --m 32
        --enable_gpu true
        -profile laptop

    ------------------------------------------------------------
    """
    System.exit(0)
}

// Parameter validation function
def validateParams(params) {
    def required_params = ['mode', 'input_dir', 'sample_sheet', 'output_dir', 'db_root']
    def missing = required_params.findAll { !params[it] }
    
    if (missing) {
        log.error "Missing required parameter(s): ${missing.join(', ')}"
        log.info  "Use --help, --h to see all available options."
        System.exit(1)
    }
    
    return true
}