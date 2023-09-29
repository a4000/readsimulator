//
// Simulate amplicon reads
//

include { CRABS_DBDOWNLOAD  } from '../../modules/local/crabs_dbdownload'
include { CRABS_DBIMPORT    } from '../../modules/local/crabs_dbimport'
include { CRABS_INSILICOPCR } from '../../modules/local/crabs_insilicopcr'
include { ART_ILLUMINA      } from '../../modules/nf-core/art/illumina/main'

workflow AMPLICON_WORKFLOW {
    ch_versions = Channel.empty()

    take:
    ch_fasta // file: /path/to/reference.fasta
    ch_input // channel: [ meta ]

    main:
    ch_ref_fasta = Channel.empty()
    if ( params.fasta ) {
        CRABS_DBDOWNLOAD ()
        ch_versions = ch_versions.mix(CRABS_DBDOWNLOAD.out.versions.first())
        ch_ref_fasta = CRABS_DBDOWNLOAD.out.fasta
            .map {
                fasta ->
                    def meta = [:]
                    meta.id = "amplicon"
                    return [ meta, fasta ]
            }

    } else {
        ch_meta_fasta = Channel.fromPath(params.fasta)
            .map {
                fasta ->
                    def meta = [:]
                    meta.id = "amplicon"
                    return [ meta, fasta ]
            }

        //
        // MODULE: Run Crabs db_import
        //
        CRABS_DBIMPORT (
            ch_meta_fasta
        )
        ch_versions = ch_versions.mix(CRABS_DBIMPORT.out.versions.first())
        ch_ref_fasta = CRABS_DBIMPORT.out.fasta
    }

    //
    // MODULE: Run Crabs insilico_pcr
    //
    CRABS_INSILICOPCR (
        ch_ref_fasta
    )
    ch_versions = ch_versions.mix(CRABS_INSILICOPCR.out.versions.first())

    // Now that we have processed our fasta file,
    // we need to map it to our sample data
    ch_art_input = CRABS_INSILICOPCR.out.fasta
        .combine ( ch_input )
        .map {
            it = [ it[2], it[1] ]
        }

    //
    // MODULE: Simulate Illumina reads
    //
    ART_ILLUMINA (
        ch_art_input,
        "HS25",
        130
    )
    ch_versions = ch_versions.mix(ART_ILLUMINA.out.versions.first())

    emit:
    reads    = ART_ILLUMINA.out.fastq // channel: [ meta, fastq ]
    versions = ch_versions            // channel: [ versions.yml ]
}