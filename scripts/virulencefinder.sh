#!/usr/bin/env bash

set -euo pipefail

SAMPLE_ID="$1"
FASTA="$2"
RMLST_TSV="$3"
OUTDIR="$4"
VF_DB="$5"

shift 5
EXTRA_ARGS="$@"

mkdir -p "${OUTDIR}"

VF_DB="$(readlink -f "${VF_DB}" 2>/dev/null || echo "${VF_DB}")"

DB_VERSION_FILE="db_version.txt"
RESULT_FILE="${OUTDIR}/results_tab.tsv"
STATUS_FILE="${OUTDIR}/virulencefinder_status.tsv"

{
    echo "Database path used: ${VF_DB}"
    if [[ -d "${VF_DB}" ]]; then
        echo "Database FASTA files:"
        find "${VF_DB}" -maxdepth 1 -type f -iname "*.fsa" -printf "%f\n" | sort
    else
        echo "WARNING: Database path does not exist"
    fi
} > "${DB_VERSION_FILE}"

TAXON=$(awk -F'\t' '
    NR==1 {
        for (i=1; i<=NF; i++) {
            gsub(/\r/, "", $i)
            if (tolower($i) == "taxon") taxon_col=i
        }
        next
    }
    NR==2 && taxon_col {
        gsub(/\r/, "", $taxon_col)
        print $taxon_col
    }
' "${RMLST_TSV}" || true)

if [[ -z "${TAXON:-}" ]]; then
    TAXON=$(grep -iE "listeria|escherichia|staphylococcus|enterococcus" "${RMLST_TSV}" | head -n 1 || true)
fi

TAXON="${TAXON:-Unknown}"
TAXON_LC=$(echo "${TAXON}" | tr '[:upper:]' '[:lower:]')

VF_DATABASE=""

if echo "${TAXON_LC}" | grep -qi "listeria"; then
    VF_DATABASE="listeria"

elif echo "${TAXON_LC}" | grep -qi "staphylococcus aureus"; then
    VF_DATABASE="s.aureus_exoenzyme,s.aureus_hostimm,s.aureus_toxin"

elif echo "${TAXON_LC}" | grep -qi "escherichia coli"; then
    VF_DATABASE="virulence_ecoli,stx"

elif echo "${TAXON_LC}" | grep -qi "enterococcus faecalis"; then
    VF_DATABASE="virulence_entfm_entls"

elif echo "${TAXON_LC}" | grep -qi "enterococcus faecium"; then
    VF_DATABASE="virulence_entfm_entls"

elif echo "${TAXON_LC}" | grep -qi "enterococcus"; then
    VF_DATABASE="virulence_ent"
fi

if [[ -z "${VF_DATABASE}" ]]; then
    echo -e "Database\tVirulence factor\tIdentity\tQuery / Template length\tContig\tPosition in contig\tProtein function\tAccession number" > "${RESULT_FILE}"

    {
        echo -e "sample_id\trmlst_taxon\tstatus\treason\tvf_db\tavailable_fsa"
        echo -e "${SAMPLE_ID}\t${TAXON}\tskipped\tNo supported species detected from rMLST\t${VF_DB}\t$(find "${VF_DB}" -maxdepth 1 -type f -iname "*.fsa" -printf "%f," 2>/dev/null || true)"
    } > "${STATUS_FILE}"

    exit 0
fi

VF_TMP="${OUTDIR}/vf_run"
mkdir -p "${VF_TMP}"

python -m virulencefinder \
    -ifa "${FASTA}" \
    -p "${VF_DB}" \
    -d "${VF_DATABASE}" \
    -o "${VF_TMP}" \
    -j "${VF_TMP}/${SAMPLE_ID}.json" \
    -b "$(which blastn)" \
    ${EXTRA_ARGS} \
    -q

VF_RESULT="${VF_TMP}/results_tab.tsv"

if [[ -s "${VF_RESULT}" ]]; then
    cp "${VF_RESULT}" "${RESULT_FILE}"
else
    echo -e "Database\tVirulence factor\tIdentity\tQuery / Template length\tContig\tPosition in contig\tProtein function\tAccession number" > "${RESULT_FILE}"
fi

{
    echo -e "sample_id\trmlst_taxon\tstatus\treason"
    echo -e "${SAMPLE_ID}\t${TAXON}\trun\tDatabase used: ${VF_DATABASE}"
} > "${STATUS_FILE}"