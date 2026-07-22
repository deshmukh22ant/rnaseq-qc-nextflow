#!/usr/bin/env nextflow

include { FASTP }   from './modules/fastp.nf'
include { FASTQC }  from './modules/fastqc.nf'
include { MULTIQC } from './modules/multiqc.nf'

workflow {
    reads_ch = Channel
        .fromPath(params.input)
        .splitCsv(header: true)
        .map { row -> tuple(row.sample, file(row.fastq)) }

    FASTP(reads_ch)
    FASTQC(FASTP.out.trimmed)
    MULTIQC( FASTQC.out.zip.mix(FASTP.out.json).collect() )
}