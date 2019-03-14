#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Defaults
INTEGRATOR_REFERENCE_DEFAULT="master"
GENERATION_BIN_REFERENCE_DEFAULT="master"

function usage() {
    cat <<EOF

Construct the integrator directory tree

Usage: $(basename $0) -i INTEGRATOR_REFERENCE -b GENERATION_BIN_REFERENCE

where

(o) -b GENERATION_BIN_REFERENCE is the git reference for the generation framework bin repo
    -h                          shows this text
(o) -i INTEGRATOR_REFERENCE     is the git reference for the integrator repo

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

INTEGRATOR_REFERENCE = ${INTEGRATOR_REFERENCE_DEFAULT}
GENERATION_BIN_REFERENCE = ${GENERATION_BIN_REFERENCE_DEFAULT}

NOTES:

EOF
    exit
}

# Parse options
while getopts ":b:hi:" opt; do
    case $opt in
        b)
            GENERATION_BIN_REFERENCE="${OPTARG}"
            ;;
        h)
            usage
            ;;
        i)
            INTEGRATOR_REFERENCE="${OPTARG}"
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
INTEGRATOR_REFERENCE="${INTEGRATOR_REFERENCE:-$INTEGRATOR_REFERENCE_DEFAULT}"
GENERATION_BIN_REFERENCE="${GENERATION_BIN_REFERENCE:-$GENERATION_BIN_REFERENCE_DEFAULT}"

# Save for later steps
echo "INTEGRATOR_REFERENCE=${INTEGRATOR_REFERENCE}" >> ${AUTOMATION_DATA_DIR}/context.properties

# Define the top level directory representing the account
BASE_DIR="${AUTOMATION_DATA_DIR}"

# Pull in the integrator repo
INTEGRATOR_DIR="${BASE_DIR}/${INTEGRATOR}"
git clone https://${!INTEGRATOR_GIT_CREDENTIALS_VAR}@${INTEGRATOR_GIT_DNS}/${INTEGRATOR_GIT_ORG}/${INTEGRATOR_REPO} ${INTEGRATOR_DIR}
RESULT=$?
[[ ${RESULT} -ne 0 ]] && fatal "Can't fetch the integrator repo"

echo "INTEGRATOR_DIR=${INTEGRATOR_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties

# Pull in the default generation repo
GENERATION_DIR="${BASE_DIR}/bin"
git clone https://${GENERATION_GIT_DNS}/${GENERATION_GIT_ORG}/${GENERATION_BIN_REPO} -b ${GENERATION_BIN_REFERENCE} ${GENERATION_DIR}
RESULT=$?
[[ ${RESULT} -ne 0 ]] && fatal "Can't fetch the GENERATION repo"

# echo "GENERATION_DIR=${GENERATION_DIR}/${ACCOUNT_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "GENERATION_DIR=${GENERATION_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties

# All good
RESULT=0

