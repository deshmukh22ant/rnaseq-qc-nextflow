process FASTQC {                                    // define a step named FASTQC (a reusable unit of work)

    tag "$sample_id"                                // label each task with its sample name, so logs read "FASTQC (SAMPLE1)" — just for readability

    container 'biocontainers/fastqc:v0.11.9_cv8'    // run this step inside this Docker image (FastQC is pre-installed here, pinned to this version)

    publishDir "${params.outdir}/fastqc", mode: 'copy'  // copy this step's outputs into results/fastqc/ (a tidy folder), instead of leaving them in work/

    input:                                          // declare what comes INTO this step
    tuple val(sample_id), path(reads)               // each item is a PAIR: a sample name (val = plain value) + a FASTQ file (path = an actual file)

    output:                                          // declare what comes OUT of this step
    path "*.zip", emit: zip                          // capture the .zip report(s) FastQC produces; name this output channel "zip" so main.nf can grab it via FASTQC.out.zip
    script:                    // the actual command that runs when this step executes
    """
    fastqc ${reads}          
    """
}