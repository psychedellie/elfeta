// modules/demo/echo_sample.nf
process ECHO_SAMPLE {
  publishDir 'results', mode: 'copy'

  label 'echo'
  conda 'envs/base.yml'

  input:
    tuple val(sid), val(platform), val(index)

  output:
    path "echo_${sid}.txt"

  script:
  """
  echo "SID=${sid} | PLATFORM=${platform} | INDEX=${index}" > echo_${sid}.txt
  """
}
