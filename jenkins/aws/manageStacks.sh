#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

DEPLOYMENT_MODE_UPDATE="update"
DEPLOYMENT_MODE_STOP="stop"
DEPLOYMENT_MODE_STOPSTART="stopstart"

# Defaults
DEPLOYMENT_MODE_DEFAULT="${DEPLOYMENT_MODE_UPDATE}"
TYPE_DEFAULT="application"

function usage() {
    cat <<EOF

Manage stacks for one or more slices

Usage: $(basename $0) -s SLICE_LIST -t TYPE -m DEPLOYMENT_MODE

where

    -h                  shows this text
(m) -m DEPLOYMENT_MODE  is the deployment mode
(m) -s SLICE_LIST       is the list of slices to process
(m) -t TYPE             is the template type

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

DEPLOYMENT_MODE = "${DEPLOYMENT_MODE_DEFAULT}"
TYPE = "${TYPE_DEFAULT}"

NOTES:

1. ACCOUNT, PRODUCT and SEGMENT must already be defined
2. All of the slices in SLICE_LIST must be the same type

EOF
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
            echo -e "\nInvalid option: -${OPTARG}" >&2
            exit
            ;;
        :)
            echo -e "\nOption -${OPTARG} requires an argument" >&2
            exit
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
    echo -e "\nInsufficient arguments" >&2
    exit
fi

cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT}/solutions/${SEGMENT}

for CURRENT_SLICE in ${SLICE_LIST}; do

    if [[ "${MODE}" != "${DEPLOYMENT_MODE_UPDATE}" ]]; then ${GENERATION_DIR}/manageStack.sh -s ${CURRENT_SLICE} -d; fi
    if [[ "${MODE}" != "${DEPLOYMENT_MODE_STOP}"   ]]; then ${GENERATION_DIR}/manageStack.sh -s ${CURRENT_SLICE}; fi
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo -e "\nStack operation for ${CURRENT_SLICE} slice failed" >&2
        exit
    fi
done

# All good
RESULT=0

