#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

PRODUCT_CONFIG_REFERENCE_DEFAULT="master"
PRODUCT_INFRASTRUCTURE_REFERENCE_DEFAULT="master"
GENERATION_BIN_REFERENCE_DEFAULT="master"
GENERATION_PATTERNS_REFERENCE_DEFAULT="master"
GENERATION_STARTUP_REFERENCE_DEFAULT="master"
function usage() {
    echo -e "\nConstruct the account directory tree" 
    echo -e "\nUsage: $(basename $0) -c CONFIG_REFERENCE -i INFRASTRUCTURE_REFERENCE -b GENERATION_BIN_REFERENCE -p GENERATION_PATTERNS_REFERENCE -s GENERATION_STARTUP_REFERENCE -a -r -n -f"
    echo -e "\nwhere\n"
    echo -e "(o) -a if the account directories should not be included"
    echo -e "(o) -b GENERATION_BIN_REFERENCE is the git reference for the generation framework bin repo"
    echo -e "(o) -c CONFIG_REFERENCE is the git reference for the config repo"
    echo -e "(o) -f if patterns and startup repos required - only bin repo is included by default"
    echo -e "    -h shows this text"
    echo -e "(o) -i INFRASTRUCTURE_REFERENCE is the git reference for the config repo"
    echo -e "(o) -n initialise repos if not already initialised"
    echo -e "(o) -p GENERATION_PATTERN_REFERENCE is the git reference for the generation framework patterns repo"
    echo -e "(o) -r if the product directories should not be included"
    echo -e "(o) -s GENERATION_STARTUP_REFERENCE is the git reference for the generation framework startup repo"
    echo -e "\nDEFAULTS:\n"
    echo -e "CONFIG_REFERENCE = ${PRODUCT_CONFIG_REFERENCE_DEFAULT}"
    echo -e "INFRASTRUCTURE_REFERENCE = ${PRODUCT_INFRASTRUCTURE_REFERENCE_DEFAULT}"
    echo -e "GENERATION_BIN_REFERENCE = ${GENERATION_BIN_REFERENCE_DEFAULT}"
    echo -e "GENERATION_PATTERNS_REFERENCE = ${GENERATION_PATTERNS_REFERENCE_DEFAULT}"
    echo -e "GENERATION_STARTUP_REFERENCE = ${GENERATION_STARTUP_REFERENCE_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e "1. ACCOUNT/PRODUCT details are assumed to be already defined via environment variables"
    echo -e ""
    RESULT=1
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
if [[ -z "${ACCOUNT}" ]]; then
    echo "ACCOUNT not defined"
    usage
fi

# Save for later steps
echo "PRODUCT_CONFIG_REFERENCE=${PRODUCT_CONFIG_REFERENCE}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_INFRASTRUCTURE_REFERENCE=${PRODUCT_INFRASTRUCTURE_REFERENCE}" >> ${AUTOMATION_DATA_DIR}/context.properties

# Define the top level directory representing the account
BASE_DIR="${AUTOMATION_DATA_DIR}/${ACCOUNT}"

if [[ !("${EXCLUDE_PRODUCT_DIRECTORIES}" == "true") ]]; then
    
    # Pull in the product config repo
    PRODUCT_URL="https://${!PRODUCT_GIT_CREDENTIALS_VAR}@${PRODUCT_GIT_DNS}/${PRODUCT_GIT_ORG}/${PRODUCT_CONFIG_REPO}"
    PRODUCT_DIR="${BASE_DIR}/config/${PRODUCT}"
    ${AUTOMATION_DIR}/manageRepo.sh -c -n "product config" -u "${PRODUCT_URL}" \
        -d "${PRODUCT_DIR}" -b "${PRODUCT_CONFIG_REFERENCE}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
 	    exit
    fi
    
    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${AUTOMATION_DIR}/manageRepo.sh -i -n "product config" -u "${PRODUCT_URL}" \
            -d "${PRODUCT_DIR}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            exit
        fi
    fi

    echo "PRODUCT_CONFIG_COMMIT=$(git -C ${PRODUCT_DIR} rev-parse HEAD)" >> ${AUTOMATION_DATA_DIR}/context.properties
fi

if [[ !("${EXCLUDE_ACCOUNT_DIRECTORIES}" == "true") ]]; then

    # Pull in the account config repo
    ACCOUNT_URL="https://${!ACCOUNT_GIT_CREDENTIALS_VAR}@${ACCOUNT_GIT_DNS}/${ACCOUNT_GIT_ORG}/${ACCOUNT_CONFIG_REPO}"
    ACCOUNT_DIR="${BASE_DIR}/config/${ACCOUNT}"
    ${AUTOMATION_DIR}/manageRepo.sh -c -n "account config" -u "${ACCOUNT_URL}" \
        -d "${ACCOUNT_DIR}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        exit
    fi

    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${AUTOMATION_DIR}/manageRepo.sh -i -n "account config" -u "${ACCOUNT_URL}" \
            -d "${ACCOUNT_DIR}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            exit
        fi
    fi
fi

# Pull in the default generation repo if not overridden by product or locally installed
if [[ -z "${GENERATION_DIR}" ]]; then
    GENERATION_DIR="${BASE_DIR}/config/bin"
    if [[ -d ${BASE_DIR}/config/${PRODUCT}/bin ]]; then
        mkdir -p "${GENERATION_DIR}"
        cp -rp ${BASE_DIR}/config/${PRODUCT}/bin "${GENERATION_DIR}"
    else
        GENERATION_URL="https://${GENERATION_GIT_DNS}/${GENERATION_GIT_ORG}/${GENERATION_BIN_REPO}"
        ${AUTOMATION_DIR}/manageRepo.sh -c -n "generation bin" -u "${GENERATION_URL}" \
            -d "${GENERATION_DIR}" -b "${GENERATION_BIN_REFERENCE}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            exit
        fi
    fi
    # echo "GENERATION_DIR=${GENERATION_DIR}/${ACCOUNT_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
    echo "GENERATION_DIR=${GENERATION_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties
fi

# Pull in the patterns repo if not overridden by product or locally installed
if [[ -z "${GENERATION_PATTERNS_DIR}" ]]; then
    if [[ "${INCLUDE_ALL_REPOS}" == "true" ]]; then
        GENERATION_PATTERNS_DIR="${BASE_DIR}/config/patterns"
        if [[ -d ${BASE_DIR}/config/${PRODUCT}/patterns ]]; then
            mkdir -p "${GENERATION_PATTERNS_DIR}"
            cp -rp ${BASE_DIR}/config/${PRODUCT}/patterns "${GENERATION_PATTERNS_DIR}"
        else
            GENERATION_URL="https://${GENERATION_GIT_DNS}/${GENERATION_GIT_ORG}/${GENERATION_PATTERNS_REPO}"
            ${AUTOMATION_DIR}/manageRepo.sh -c -n "generation patterns" -u "${GENERATION_URL}" \
                -d "${GENERATION_PATTERNS_DIR}" -b "${GENERATION_PATTERNS_REFERENCE}"
            RESULT=$?
            if [[ ${RESULT} -ne 0 ]]; then
                exit
            fi
        fi
    #    echo "GENERATION_PATTERNS_DIR=${GENERATION_PATTERNS_DIR}/${ACCOUNT_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
        echo "GENERATION_PATTERNS_DIR=${GENERATION_PATTERNS_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties
    fi
fi

if [[ !("${EXCLUDE_PRODUCT_DIRECTORIES}" == "true") ]]; then
    
    # Pull in the product infrastructure repo
    PRODUCT_URL="https://${!PRODUCT_GIT_CREDENTIALS_VAR}@${PRODUCT_GIT_DNS}/${PRODUCT_GIT_ORG}/${PRODUCT_INFRASTRUCTURE_REPO}"
    PRODUCT_DIR="${BASE_DIR}/infrastructure/${PRODUCT}"
    ${AUTOMATION_DIR}/manageRepo.sh -c -n "product infrastructure" -u "${PRODUCT_URL}" \
        -d "${PRODUCT_DIR}" -b "${PRODUCT_INFRASTRUCTURE_REFERENCE}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
 	    exit
    fi
    
    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${AUTOMATION_DIR}/manageRepo.sh -i -n "product infrastructure" -u "${PRODUCT_URL}" \
            -d "${PRODUCT_DIR}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            exit
        fi
    fi

    echo "PRODUCT_INFRASTRUCTURE_COMMIT=$(git -C ${PRODUCT_DIR} rev-parse HEAD)" >> ${AUTOMATION_DATA_DIR}/context.properties
fi

if [[ !("${EXCLUDE_ACCOUNT_DIRECTORIES}" == "true") ]]; then

    # Pull in the account infrastructure repo
    ACCOUNT_URL="https://${!ACCOUNT_GIT_CREDENTIALS_VAR}@${ACCOUNT_GIT_DNS}/${ACCOUNT_GIT_ORG}/${ACCOUNT_INFRASTRUCTURE_REPO}"
    ACCOUNT_DIR="${BASE_DIR}/infrastructure/${ACCOUNT}"
    ${AUTOMATION_DIR}/manageRepo.sh -c -n "account infrastructure" -u "${ACCOUNT_URL}" \
        -d "${ACCOUNT_DIR}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        exit
    fi

    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${AUTOMATION_DIR}/manageRepo.sh -i -n "account infrastructure" -u "${ACCOUNT_URL}" \
            -d "${ACCOUNT_DIR}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            exit
        fi
    fi
fi

# Pull in the default generation startup repo if not overridden by product or locally installed
if [[ -z "${GENERATION_STARTUP_DIR}" ]]; then
    if [[ "${INCLUDE_ALL_REPOS}" == "true" ]]; then
        GENERATION_STARTUP_DIR="${BASE_DIR}/infrastructure/startup"
        if [[ -d ${BASE_DIR}/infrastructure/${PRODUCT}/startup ]]; then
            mkdir -p "${GENERATION_STARTUP_DIR}"
            cp -rp ${BASE_DIR}/infrastructure/${PRODUCT}/startup "${GENERATION_STARTUP_DIR}"
        else
            GENERATION_URL="https://${GENERATION_GIT_DNS}/${GENERATION_GIT_ORG}/${GENERATION_STARTUP_REPO}"
            ${AUTOMATION_DIR}/manageRepo.sh -c -n "generation startup" -u "${GENERATION_URL}" \
                -d "${GENERATION_STARTUP_DIR}" -b "${GENERATION_STARTUP_REFERENCE}"
            RESULT=$?
            if [[ ${RESULT} -ne 0 ]]; then
                exit
            fi
        fi
        echo "GENERATION_STARTUP_DIR=${GENERATION_STARTUP_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties
    fi
fi

# All good
RESULT=0

