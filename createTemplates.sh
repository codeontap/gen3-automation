#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

TYPE_DEFAULT="application"
function usage() {
    echo -e "\nGenerate templates for one or more slices"
    echo -e "\nUsage: $(basename $0) -s SLICE_LIST -c CONFIGURATION_REFERENCE -r REQUEST -t TYPE"
    echo -e "\nwhere\n"
    echo -e "(m) -c CONFIGURATION_REFERENCE is the id of the configuration (commit id, branch id, tag) used to generate the template"
    echo -e "    -h shows this text"
    echo -e "(o) -r REQUEST is an opaque value to link this template to a triggering request management system"
    echo -e "(m) -s SLICE_LIST is the list of slices to process"
    echo -e "(m) -t TYPE is the template type - \"account\", \"product\", \"segment\", \"solution\" or \"application\""
    echo -e "\nDEFAULTS:\n"
    echo -e "TYPE = \"${TYPE_DEFAULT}\""
    echo -e "\nNOTES:\n"
    echo -e "1. ACCOUNT, PRODUCT and SEGMENT must already be defined"
    echo -e "2. All of the slices in SLICE_LIST must be the same type"
    exit
}

# Parse options
while getopts ":c:hr:s:t:" opt; do
    case $opt in
        c)
            export CONFIGURATION_REFERENCE="${OPTARG}"
            ;;
        h)
            usage
            ;;
        r)
            export REQUEST="${OPTARG}"
            ;;
        s)
            SLICE_LIST="${OPTARG}"
            ;;
        t)
            TYPE="${OPTARG}"
            ;;
        \?)
            echo -e "\nInvalid option: -${OPTARG}"
            usage
            ;;
        :)
            echo -e "\nOption -${OPTARG} requires an argument"
            usage
            ;;
     esac
done

# Apply defaults
export TYPE="${TYPE:-${TYPE_DEFAULT}}"

# Ensure mandatory arguments have been provided
if [[ (-z "${CONFIGURATION_REFERENCE}") ||
        (-z "${SLICE_LIST}") ||
        (-z "${TYPE}") ]]; then
    echo -e "\nInsufficient arguments"
    usage
fi

cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT}/solutions/${SEGMENT}

for CURRENT_SLICE in ${SLICE_LIST}; do

    # Generate the template for each slice
    ${GENERATION_DIR}/createTemplate.sh -s "${CURRENT_SLICE}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
 		echo -e "\nGeneration of template for slice ${CURRENT_SLICE} failed"
        exit
    fi

done

# All good
RESULT=0

