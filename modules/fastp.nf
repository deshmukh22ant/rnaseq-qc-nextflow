process FASTP {
    tag "$sample_id"
    container 'quay.io/biocontainers/fastp:0.23.4--h5f740d0_0'
    publishDir "${params.outdir}/fastp", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}.trimmed.fastq.gz"), emit: trimmed
    path "${sample_id}.fastp.json", emit: json

    script:
    """
    fastp \\
        -i ${reads} \\
        -o ${sample_id}.trimmed.fastq.gz \\
        --json ${sample_id}.fastp.json
    """
}