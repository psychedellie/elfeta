process NORMALIZE_SHORTREADS {
    tag "normalize_shortreads"
    label 'preprocessing'
    publishDir "${params.outdir}", mode: 'copy'

    input:
        path input_dir

    output:
        path "samples.tsv", emit: samples_tsv

    script:
    """
    # Make sure input path is absolute so find works correctly
    in_dir=\$(realpath "${input_dir}")
    
    echo "[NORMALIZE_SHORTREADS] Creating sample mapping from: \$in_dir"
    ls -1 \$in_dir | head -n 10 || echo "[NORMALIZE_SHORTREADS] (no preview)"

    bash ${params.scripts_dir}/normalize_shortreads.sh "\$in_dir" "." || {
        echo "❌ Normalization failed, check input directory!"
        exit 1
    }

    echo "[NORMALIZE_SHORTREADS] Done. Wrote samples.tsv"
    """
}