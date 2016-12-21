#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

DEPLOYMENT_MODE_DEFAULT="update"
TYPE_DEFAULT="application"
function usage() {
    echo -e "\Manage stacks for one or more slices"
    echo -e "\nUsage: $(basename $0) -s SLICE_LIST -t TYPE -m DEPLOYMENT_MODE"
    echo -e "\nwhere\n"
    echo -e "    -h shows this text"
    echo -e "(m) -m DEPLOYMENT_MODE is the deployment mode"
    echo -e "(m) -s SLICE_LIST is the list of slices to process"
    echo -e "(m) -t TYPE is the template type"
    echo -e "\nDEFAULTS:\n"
    echo -e "DEPLOYMENT_MODE = \"${DEPLOYMENT_MODE_DEFAULT}\""
    echo -e "TYPE = \"${TYPE_DEFAULT}\""
    echo -e "\nNOTES:\n"
    echo -e "1. ACCOUNT, PRODUCT and SEGMENT must already be defined"
    echo -e "2. All of the slices in SLICE_LIST must be the same type"
    exit
}

# Parse options
while getopts ":hm:s:t:" opt; do
    case $opt in
        h)
            usage
            ;;
        m)
            DEPLOYMENT_MODE="${OPTARG}"
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
export DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-${DEPLOYMENT_MODE_DEFAULT}}"
export TYPE="${TYPE:-${TYPE_DEFAULT}}"

# Ensure mandatory arguments have been provided
if [[ (-z "${DEPLOYMENT_MODE}") ||
       (-z "${SLICE_LIST}") ||
       (-z "${TYPE}") ]]; then
    echo -e "\nInsufficient arguments"
    usage
fi

cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT}/solutions/${SEGMENT}

for CURRENT_SLICE in ${SLICE_LIST}; do

    if [[ "${MODE}" != "update" ]]; then ${GENERATION_DIR}/manageStack.sh -s ${CURRENT_SLICE} -d; fi
    if [[ "${MODE}" != "stop"   ]]; then ${GENERATION_DIR}/manageStack.sh -s ${CURRENT_SLICE}; fi
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo -e "\nStack operation for ${CURRENT_SLICE} slice failed"
        exit
    fi
done

# All good
RESULT=0

