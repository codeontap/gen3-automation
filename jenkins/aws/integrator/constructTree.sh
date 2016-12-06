#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

INTEGRATOR_REFERENCE_DEFAULT="master"
GENERATION_BIN_REFERENCE_DEFAULT="master"
function usage() {
    echo -e "\nConstruct the integrator directory tree" 
    echo -e "\nUsage: $(basename $0) -i INTEGRATOR_REFERENCE -b GENERATION_BIN_REFERENCE"
    echo -e "\nwhere\n"
    echo -e "(o) -b GENERATION_BIN_REFERENCE is the git reference for the generation framework bin repo"
    echo -e "    -h shows this text"
    echo -e "(o) -i INTEGRATOR_REFERENCE is the git reference for the integrator repo"
    echo -e "\nDEFAULTS:\n"
    echo -e "INTEGRATOR_REFERENCE = ${INTEGRATOR_REFERENCE_DEFAULT}"
    echo -e "GENERATION_BIN_REFERENCE = ${GENERATION_BIN_REFERENCE_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e ""
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
if [[ ${RESULT} -ne 0 ]]; then
    echo -e "\nCan't fetch the integrator repo"
    exit
fi
echo "INTEGRATOR_DIR=${INTEGRATOR_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties

# Pull in the default generation repo
GENERATION_DIR="${BASE_DIR}/bin"
git clone https://${GENERATION_GIT_DNS}/${GENERATION_GIT_ORG}/${GENERATION_BIN_REPO} -b ${GENERATION_BIN_REFERENCE} ${GENERATION_DIR}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
    echo -e "\nCan't fetch the GENERATION repo"
    exit
fi
# echo "GENERATION_DIR=${GENERATION_DIR}/${ACCOUNT_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "GENERATION_DIR=${GENERATION_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties

# All good
RESULT=0

