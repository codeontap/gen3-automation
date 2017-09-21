#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${GENERATION_DIR}/common.sh"

DEPLOYMENT_MODE_UPDATE="update"
DEPLOYMENT_MODE_STOP="stop"
DEPLOYMENT_MODE_STOPSTART="stopstart"

# Defaults
DEPLOYMENT_MODE_DEFAULT="${DEPLOYMENT_MODE_UPDATE}"
TYPE_DEFAULT="application"

function usage() {
    cat <<EOF

Manage stacks for one or more deployment units

Usage: $(basename $0) -s DEPLOYMENT_UNIT_LIST -t TYPE -m DEPLOYMENT_MODE

where

    -h                      shows this text
(m) -m DEPLOYMENT_MODE      is the deployment mode
(d) -s DEPLOYMENT_UNIT_LIST same as -u
(m) -t TYPE                 is the template type
(m) -u DEPLOYMENT_UNIT_LIST is the list of deployment units to process

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

DEPLOYMENT_MODE = "${DEPLOYMENT_MODE_DEFAULT}"
TYPE = "${TYPE_DEFAULT}"

NOTES:

1. ACCOUNT, PRODUCT and SEGMENT must already be defined
2. All of the deployment units in DEPLOYMENT_UNIT_LIST must be the same type

EOF
}

# Parse options
while getopts ":hm:s:t:u:" opt; do
    case $opt in
        h)
            usage
            ;;
        m)
            DEPLOYMENT_MODE="${OPTARG}"
            ;;
        s)
            DEPLOYMENT_UNIT_LIST="${OPTARG}"
            ;;
        t)
            TYPE="${OPTARG}"
            ;;
        u)
            DEPLOYMENT_UNIT_LIST="${OPTARG}"
            ;;
        \?)
            fatalOption
            ;;
        :)
            fatalOptionArgument
            ;;
     esac
done

# Apply defaults
export DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-${DEPLOYMENT_MODE_DEFAULT}}"
export TYPE="${TYPE:-${TYPE_DEFAULT}}"

# Ensure mandatory arguments have been provided
[[ (-z "${DEPLOYMENT_MODE}") ||
    (-z "${DEPLOYMENT_UNIT_LIST}") ||
    (-z "${TYPE}") ]] && fatalMandatory

cd $(findGen3SegmentDir "${AUTOMATION_DATA_DIR}/${ACCOUNT}" "${PRODUCT}" "${SEGMENT}")

for CURRENT_DEPLOYMENT_UNIT in ${DEPLOYMENT_UNIT_LIST}; do

    if [[ "${MODE}" != "${DEPLOYMENT_MODE_UPDATE}" ]]; then ${GENERATION_DIR}/manageStack.sh -u ${CURRENT_DEPLOYMENT_UNIT} -d; fi
    if [[ "${MODE}" != "${DEPLOYMENT_MODE_STOP}"   ]]; then ${GENERATION_DIR}/manageStack.sh -u ${CURRENT_DEPLOYMENT_UNIT}; fi
    RESULT=$?
    [[ ${RESULT} -ne 0 ]] && \
        fatal "Stack operation for ${CURRENT_DEPLOYMENT_UNIT} deployment unit failed"
done

# All good
RESULT=0

