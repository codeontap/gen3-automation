#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

REFERENCE_MASTER="master"

# Defaults
PRODUCT_CONFIG_REFERENCE_DEFAULT="${REFERENCE_MASTER}"
PRODUCT_INFRASTRUCTURE_REFERENCE_DEFAULT="${REFERENCE_MASTER}"
GENERATION_BIN_REFERENCE_DEFAULT="${REFERENCE_MASTER}"
GENERATION_PATTERNS_REFERENCE_DEFAULT="${REFERENCE_MASTER}"
GENERATION_STARTUP_REFERENCE_DEFAULT="${REFERENCE_MASTER}"

function usage() {
    cat <<EOF

Construct the account directory tree

Usage: $(basename $0) -c CONFIG_REFERENCE -i INFRASTRUCTURE_REFERENCE -b GENERATION_BIN_REFERENCE -p GENERATION_PATTERNS_REFERENCE -s GENERATION_STARTUP_REFERENCE -a -r -n -f

where

(o) -a                                  if the account directories should not be included
(o) -b GENERATION_BIN_REFERENCE         is the git reference for the generation framework bin repo
(o) -c CONFIG_REFERENCE                 is the git reference for the config repo
(o) -f                                  if patterns and startup repos required - only bin repo is included by default
    -h                                  shows this text
(o) -i INFRASTRUCTURE_REFERENCE         is the git reference for the config repo
(o) -n                                  initialise repos if not already initialised
(o) -p GENERATION_PATTERNS_REFERENCE    is the git reference for the generation framework patterns repo
(o) -r                                  if the product directories should not be included
(o) -s GENERATION_STARTUP_REFERENCE     is the git reference for the generation framework startup repo

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

CONFIG_REFERENCE = ${PRODUCT_CONFIG_REFERENCE_DEFAULT}
INFRASTRUCTURE_REFERENCE = ${PRODUCT_INFRASTRUCTURE_REFERENCE_DEFAULT}
GENERATION_BIN_REFERENCE = ${GENERATION_BIN_REFERENCE_DEFAULT}
GENERATION_PATTERNS_REFERENCE = ${GENERATION_PATTERNS_REFERENCE_DEFAULT}
GENERATION_STARTUP_REFERENCE = ${GENERATION_STARTUP_REFERENCE_DEFAULT}

NOTES:

1. ACCOUNT/PRODUCT details are assumed to be already defined via environment variables

EOF
    exit
}

# Parse options
while getopts ":ab:c:fhi:np:rs:" opt; do
    case $opt in
        a)
            EXCLUDE_ACCOUNT_DIRECTORIES="true"
            ;;
        b)
            GENERATION_BIN_REFERENCE="${OPTARG}"
            ;;
        c)
            PRODUCT_CONFIG_REFERENCE="${OPTARG}"
            ;;
        f)
            INCLUDE_ALL_REPOS="true"
            ;;
        h)
            usage
            ;;
        i)
            PRODUCT_INFRASTRUCTURE_REFERENCE="${OPTARG}"
            ;;
        n)
            INIT_REPOS="true"
            ;;
        p)
            GENERATION_PATTERNS_REFERENCE="${OPTARG}"
            ;;
        r)
            EXCLUDE_PRODUCT_DIRECTORIES="true"
            ;;
        s)
            GENERATION_STARTUP_REFERENCE="${OPTARG}"
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
PRODUCT_CONFIG_REFERENCE="${PRODUCT_CONFIG_REFERENCE:-$PRODUCT_CONFIG_REFERENCE_DEFAULT}"
PRODUCT_INFRASTRUCTURE_REFERENCE="${PRODUCT_INFRASTRUCTURE_REFERENCE:-$PRODUCT_INFRASTRUCTURE_REFERENCE_DEFAULT}"
GENERATION_BIN_REFERENCE="${GENERATION_BIN_REFERENCE:-$GENERATION_BIN_REFERENCE_DEFAULT}"
GENERATION_PATTERNS_REFERENCE="${GENERATION_PATTERNS_REFERENCE:-$GENERATION_PATTERNS_REFERENCE_DEFAULT}"
GENERATION_STARTUP_REFERENCE="${GENERATION_STARTUP_REFERENCE:-$GENERATION_STARTUP_REFERENCE_DEFAULT}"
EXCLUDE_ACCOUNT_DIRECTORIES="${EXCLUDE_ACCOUNT_DIRECTORIES:-false}"
EXCLUDE_PRODUCT_DIRECTORIES="${EXCLUDE_PRODUCT_DIRECTORIES:-false}"
INCLUDE_ALL_REPOS="${INCLUDE_ALL_REPOS:-false}"
INIT_REPOS="${INIT_REPOS:-false}"

# Check for required context
[[ -z "${ACCOUNT}" ]] && fatal "ACCOUNT not defined"

# Save for later steps
echo "PRODUCT_CONFIG_REFERENCE=${PRODUCT_CONFIG_REFERENCE}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_INFRASTRUCTURE_REFERENCE=${PRODUCT_INFRASTRUCTURE_REFERENCE}" >> ${AUTOMATION_DATA_DIR}/context.properties

# Define the top level directory representing the account
BASE_DIR="${AUTOMATION_DATA_DIR}/${ACCOUNT}"

if [[ !("${EXCLUDE_PRODUCT_DIRECTORIES}" == "true") ]]; then
    
    # Pull in the product config repo
    PRODUCT_DIR="${BASE_DIR}/config/${PRODUCT}"
    ${AUTOMATION_DIR}/manageRepo.sh -c -l "product config" \
        -n "${PRODUCT_CONFIG_REPO}" -v "${PRODUCT_GIT_PROVIDER}" \
        -d "${PRODUCT_DIR}" -b "${PRODUCT_CONFIG_REFERENCE}"
    RESULT=$?
    [[ ${RESULT} -ne 0 ]] && exit
    
    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${AUTOMATION_DIR}/manageRepo.sh -i -l "product config" \
            -n "${PRODUCT_CONFIG_REPO}" -v "${PRODUCT_GIT_PROVIDER}" \
            -d "${PRODUCT_DIR}"
        RESULT=$?
        [[ ${RESULT} -ne 0 ]] && exit
    fi
    
    # Accommodate multi-product repos
    PRODUCT_SUB_DIR="$(findSubDir "${PRODUCT}/product.json" "${PRODUCT_DIR}")"
    [[ -n "${PRODUCT_SUB_DIR}" ]] && \
        PRODUCT_DIR="${BASE_DIR}/config/products" &&
        mv "${BASE_DIR}/config/${PRODUCT}" "${PRODUCT_DIR}"

    echo "PRODUCT_CONFIG_COMMIT=$(git -C ${PRODUCT_DIR} rev-parse HEAD)" >> ${AUTOMATION_DATA_DIR}/context.properties
fi

if [[ !("${EXCLUDE_ACCOUNT_DIRECTORIES}" == "true") ]]; then

    # Pull in the account config repo
    ACCOUNT_DIR="${BASE_DIR}/config/${ACCOUNT}"
    ${AUTOMATION_DIR}/manageRepo.sh -c -l "account config" \
        -n "${ACCOUNT_CONFIG_REPO}" -v "${ACCOUNT_GIT_PROVIDER}" \
        -d "${ACCOUNT_DIR}"
    RESULT=$?
    [[ ${RESULT} -ne 0 ]] && exit

    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${AUTOMATION_DIR}/manageRepo.sh -i -l "account config" \
            -n "${ACCOUNT_CONFIG_REPO}" -v "${ACCOUNT_GIT_PROVIDER}" \
            -d "${ACCOUNT_DIR}"
        RESULT=$?
        [[ ${RESULT} -ne 0 ]] && exit
    fi

    # Accommodate multi-account repos
    ACCOUNT_SUB_DIR="$(findSubDir "${ACCOUNT}/account.json" "${ACCOUNT_DIR}")"
    [[ -n "${ACCOUNT_SUB_DIR}" ]] && \
        ACCOUNT_DIR="${BASE_DIR}/config/accounts" &&
        mv "${BASE_DIR}/config/${ACCOUNT}" "${ACCOUNT_DIR}"
fi

# Pull in the default generation repo if not overridden by product or locally installed
if [[ -z "${GENERATION_DIR}" ]]; then
    GENERATION_DIR="${BASE_DIR}/config/bin"
    if [[ -d ${BASE_DIR}/config/${PRODUCT}/bin ]]; then
        mkdir -p "${GENERATION_DIR}"
        cp -rp ${BASE_DIR}/config/${PRODUCT}/bin "${GENERATION_DIR}"
    else
        ${AUTOMATION_DIR}/manageRepo.sh -c -l "generation bin" \
            -n "${GENERATION_BIN_REPO}" -v "${GENERATION_GIT_PROVIDER}" \
            -d "${GENERATION_DIR}" -b "${GENERATION_BIN_REFERENCE}"
        RESULT=$?
        [[ ${RESULT} -ne 0 ]] && exit
    fi
    echo "GENERATION_DIR=${GENERATION_DIR}/${ACCOUNT_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
fi

# Pull in the patterns repo if not overridden by product or locally installed
if [[ -z "${GENERATION_PATTERNS_DIR}" ]]; then
    if [[ "${INCLUDE_ALL_REPOS}" == "true" ]]; then
        GENERATION_PATTERNS_DIR="${BASE_DIR}/config/patterns"
        if [[ -d ${BASE_DIR}/config/${PRODUCT}/patterns ]]; then
            mkdir -p "${GENERATION_PATTERNS_DIR}"
            cp -rp ${BASE_DIR}/config/${PRODUCT}/patterns "${GENERATION_PATTERNS_DIR}"
        else
            ${AUTOMATION_DIR}/manageRepo.sh -c -l "generation patterns" \
                -n "${GENERATION_PATTERNS_REPO}" -v "${GENERATION_GIT_PROVIDER}" \
                -d "${GENERATION_PATTERNS_DIR}" -b "${GENERATION_PATTERNS_REFERENCE}"
            RESULT=$?
            [[ ${RESULT} -ne 0 ]] && exit
        fi
        echo "GENERATION_PATTERNS_DIR=${GENERATION_PATTERNS_DIR}/${ACCOUNT_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
    fi
fi

if [[ !("${EXCLUDE_PRODUCT_DIRECTORIES}" == "true") ]]; then
    
    # Pull in the product infrastructure repo
    PRODUCT_DIR="${BASE_DIR}/infrastructure/${PRODUCT}"
    ${AUTOMATION_DIR}/manageRepo.sh -c -l "product infrastructure" \
        -n "${PRODUCT_INFRASTRUCTURE_REPO}" -v "${PRODUCT_GIT_PROVIDER}" \
        -d "${PRODUCT_DIR}" -b "${PRODUCT_INFRASTRUCTURE_REFERENCE}"
    RESULT=$?
    [[ ${RESULT} -ne 0 ]] && exit
    
    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${AUTOMATION_DIR}/manageRepo.sh -i -l "product infrastructure" \
            -n "${PRODUCT_INFRASTRUCTURE_REPO}" -v "${PRODUCT_GIT_PROVIDER}" \
            -d "${PRODUCT_DIR}"
        RESULT=$?
        [[ ${RESULT} -ne 0 ]] && exit
    fi

    # Accommodate multi-product repos
    PRODUCT_SUB_DIR="$(findSubDir "${PRODUCT}" "${PRODUCT_DIR}")"
    [[ -n "${PRODUCT_SUB_DIR}" ]] && \
        PRODUCT_DIR="${BASE_DIR}/infrastructure/products" &&
        mv "${BASE_DIR}/infrastructure/${PRODUCT}" "${PRODUCT_DIR}"

    echo "PRODUCT_INFRASTRUCTURE_COMMIT=$(git -C ${PRODUCT_DIR} rev-parse HEAD)" >> ${AUTOMATION_DATA_DIR}/context.properties
fi

if [[ !("${EXCLUDE_ACCOUNT_DIRECTORIES}" == "true") ]]; then

    # Pull in the account infrastructure repo
    ACCOUNT_DIR="${BASE_DIR}/infrastructure/${ACCOUNT}"
    ${AUTOMATION_DIR}/manageRepo.sh -c -l "account infrastructure" \
        -n "${ACCOUNT_INFRASTRUCTURE_REPO}" -v "${ACCOUNT_GIT_PROVIDER}" \
        -d "${ACCOUNT_DIR}"
    RESULT=$?
    [[ ${RESULT} -ne 0 ]] && exit

    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${AUTOMATION_DIR}/manageRepo.sh -i -l "account infrastructure" \
            -n "${ACCOUNT_INFRASTRUCTURE_REPO}" -v "${ACCOUNT_GIT_PROVIDER}" \
            -d "${ACCOUNT_DIR}"
        RESULT=$?
        [[ ${RESULT} -ne 0 ]] && exit
    fi

    # Accommodate multi-account repos
    ACCOUNT_SUB_DIR="$(findSubDir "${ACCOUNT}" "${ACCOUNT_DIR}")"
    [[ -n "${ACCOUNT_SUB_DIR}" ]] && \
        ACCOUNT_DIR="${BASE_DIR}/infrastructure/accounts" &&
        mv "${BASE_DIR}/infrastructure/${ACCOUNT}" "${ACCOUNT_DIR}"
fi

# Pull in the default generation startup repo if not overridden by product or locally installed
if [[ -z "${GENERATION_STARTUP_DIR}" ]]; then
    if [[ "${INCLUDE_ALL_REPOS}" == "true" ]]; then
        GENERATION_STARTUP_DIR="${BASE_DIR}/infrastructure/startup"
        if [[ -d ${BASE_DIR}/infrastructure/${PRODUCT}/startup ]]; then
            mkdir -p "${GENERATION_STARTUP_DIR}"
            cp -rp ${BASE_DIR}/infrastructure/${PRODUCT}/startup "${GENERATION_STARTUP_DIR}"
        else
            ${AUTOMATION_DIR}/manageRepo.sh -c -l "generation startup" \
                -n "${GENERATION_STARTUP_REPO}" -v "${GENERATION_GIT_PROVIDER}" \
                -d "${GENERATION_STARTUP_DIR}" -b "${GENERATION_STARTUP_REFERENCE}"
            RESULT=$?
            [[ ${RESULT} -ne 0 ]] && exit
        fi
        echo "GENERATION_STARTUP_DIR=${GENERATION_STARTUP_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties
    fi
fi

# All good
RESULT=0

