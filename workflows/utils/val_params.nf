include { SHOW_HELP }               from './help_utils.nf'

// Parameter validation function
def VAL_PARAMS(params) {
    // Define required parameters for main analysis
    def required_parameters = ['mode', 'input_dir', 'sample_sheet', 'output_dir', 'db_root']
    def missing_parameters = required_parameters.findAll { parameter_name -> !params[parameter_name] }

    // Display help if requested
    if (params.help || params.h) {
        SHOW_HELP()
    }

    // Check for database setup mode
    if (params.db_setup) {
        // For database setup, only db_root is required
        if (!params.db_root) {
            log.error "Missing required parameter: db_root"
            log.info  "Parameter --db_root is mandatory for database setup."
            log.info  "Use --help or -h to view all available options."
            System.exit(1)
        }
        return true
    }

    // Check for missing required parameters in main mode
    if (missing_parameters) {
        log.error "Missing required parameter(s): ${missing_parameters.join(', ')}"
        log.info  "Use --help or -h to view all available options."
        System.exit(1)
    }

    return true
}