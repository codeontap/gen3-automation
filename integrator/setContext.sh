#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

INTEGRATOR_DEFAULT="integrator"
function usage() {
    echo -e "\nDetermine key settings for an integrator/tenant/account" 
    echo -e "\nUsage: $(basename $0) -c INTEGRATOR -t TENANT -a ACCOUNT"
    echo -e "\nwhere\n"
    echo -e "(o) -a ACCOUNT is the tenant account name e.g. \"env01\""
    echo -e "    -h shows this text"
    echo -e "(o) -i INTEGRATOR is the integrator cyber account name"
    echo -e "(o) -t TENANT is the tenant name e.g. \"env\""
    echo -e "\nDEFAULTS:\n"
    echo -e "INTEGRATOR=${INTEGRATOR_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e "1. The setting values are saved in context.properties in the current directory"
    echo -e ""
    exit
}

# Parse options
while getopts ":a:hi:t:" opt; do
    case $opt in
        a)
            ACCOUNT="${OPTARG}"
            ;;
        h)
            usage
            ;;
        i)
            INTEGRATOR="${OPTARG}"
            ;;
        t)
            TENANT="${OPTARG}"
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

# Determine the integrator/tenant/account from the job name
# if not already defined or provided on the command line
JOB_PATH=($(echo "${JOB_NAME}" | tr "/" " "))
PARTS=()
COT_PREFIX="cot-"
for PART in ${JOB_PATH[@]}; do
    if [[ "${PART}" =~ ^${COT_PREFIX}* ]]; then
        PARTS+=("${PART#${COT_PREFIX}}")
    fi
done
PARTS_COUNT="${#PARTS[@]}"

if [[ "${PARTS_COUNT}" -gt 2 ]]; then
    # Assume its integrator/tenant/account
    INTEGRATOR=${INTEGRATOR:-${PARTS[${PARTS_COUNT}-3]}}
    TENANT=${TENANT:-${PARTS[${PARTS_COUNT}-2]}}
    ACCOUNT=${ACCOUNT:-${PARTS[${PARTS_COUNT}-1]}}
fi
if [[ "${PARTS_COUNT}" -gt 1 ]]; then
    # Assume its tenant and account
    TENANT=${TENANT:-${PARTS[${PARTS_COUNT}-2]}}
    ACCOUNT=${ACCOUNT:-${PARTS[${PARTS_COUNT}-1]}}
fi
if [[ "${PARTS_COUNT}" -gt 0 ]]; then
    # Assume its the tenant
    TENANT=${TENANT:-${PARTS[${PARTS_COUNT}-1]}}
fi

INTEGRATOR=${INTEGRATOR,,:-${INTEGRATOR_DEFAULT}}
INTEGRATOR_UPPER=${INTEGRATOR^^}

TENANT=${TENANT,,}
TENANT_UPPER=${TENANT^^}

ACCOUNT=${ACCOUNT,,}
ACCOUNT_UPPER=${ACCOUNT^^}

# Default "GITHUB" git provider
GITHUB_DNS="${GITHUB_DNS:-github.com}"
GITHUB_API_DNS="${GITHUB_API_DNS:-api.$GITHUB_DNS}"

# Determine who to include as the author if git updates required
GIT_USER="${GIT_USER:-$BUILD_USER}"
GIT_USER="${GIT_USER:-$GIT_USER_DEFAULT}"
GIT_USER="${GIT_USER:-alm}"
GIT_EMAIL="${GIT_EMAIL:-$BUILD_USER_EMAIL}"
GIT_EMAIL="${GIT_EMAIL:-$GIT_EMAIL_DEFAULT}"

# Defaults for gsgen
GSGEN_GIT_DNS="${GSGEN_GIT_DNS:-github.com}"
GSGEN_GIT_ORG="${GSGEN_GIT_ORG:-codeontap}"
GSGEN_BIN_REPO="${GSGEN_BIN_REPO:-gsgen3.git}"

# Determine the integrator account git provider
if [[ -z "${INTEGRATOR_GIT_PROVIDER}" ]]; then
    INTEGRATOR_GIT_PROVIDER_VAR="${INTEGRATOR_UPPER}_GIT_PROVIDER"
    INTEGRATOR_GIT_PROVIDER="${!INTEGRATOR_GIT_PROVIDER_VAR}"
    INTEGRATOR_GIT_PROVIDER="${INTEGRATOR_GIT_PROVIDER:-GITHUB}"
fi

INTEGRATOR_GIT_USER_VAR="${INTEGRATOR_GIT_PROVIDER}_USER"
INTEGRATOR_GIT_PASSWORD_VAR="${INTEGRATOR_GIT_PROVIDER}_PASSWORD"
INTEGRATOR_GIT_CREDENTIALS_VAR="${INTEGRATOR_GIT_PROVIDER}_CREDENTIALS"

INTEGRATOR_GIT_ORG_VAR="${INTEGRATOR_GIT_PROVIDER}_ORG"
INTEGRATOR_GIT_ORG="${!INTEGRATOR_GIT_ORG_VAR}"

INTEGRATOR_GIT_DNS_VAR="${INTEGRATOR_GIT_PROVIDER}_DNS"
INTEGRATOR_GIT_DNS="${!INTEGRATOR_GIT_DNS_VAR}"

INTEGRATOR_GIT_API_DNS_VAR="${INTEGRATOR_GIT_PROVIDER}_API_DNS"
INTEGRATOR_GIT_API_DNS="${!INTEGRATOR_GIT_API_DNS_VAR}"

# Determine integrator account repo
if [[ -z "${INTEGRATOR_REPO}" ]]; then
    INTEGRATOR_REPO_VAR="${INTEGRATOR_UPPER}_REPO"
    INTEGRATOR_REPO="${!INTEGRATOR_REPO_VAR}"
fi

# Basic details for git commits/slack notification (enhanced by other scripts)
DETAIL_MESSAGE="tenant=${TENANT}"
if [[ -n "${ACCOUNT}" ]]; then DETAIL_MESSAGE="${DETAIL_MESSAGE}, account=${ACCOUNT}"; fi
if [[ -n "${GIT_USER}" ]];  then DETAIL_MESSAGE="${DETAIL_MESSAGE}, user=${GIT_USER}"; fi

# Save for future steps
echo "INTEGRATOR=${INTEGRATOR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "TENANT=${TENANT}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "ACCOUNT=${ACCOUNT}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "GSGEN_GIT_DNS=${GSGEN_GIT_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "GSGEN_GIT_ORG=${GSGEN_GIT_ORG}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "GSGEN_BIN_REPO=${GSGEN_BIN_REPO}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "INTEGRATOR_GIT_PROVIDER=${INTEGRATOR_GIT_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "INTEGRATOR_GIT_USER_VAR=${INTEGRATOR_GIT_USER_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "INTEGRATOR_GIT_PASSWORD_VAR=${INTEGRATOR_GIT_PASSWORD_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "INTEGRATOR_GIT_CREDENTIALS_VAR=${INTEGRATOR_GIT_CREDENTIALS_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "INTEGRATOR_GIT_ORG=${INTEGRATOR_GIT_ORG}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "INTEGRATOR_GIT_DNS=${INTEGRATOR_GIT_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "INTEGRATOR_GIT_API_DNS=${INTEGRATOR_GIT_API_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "INTEGRATOR_AWS_ACCESS_KEY_ID_VAR=${INTEGRATOR_AWS_ACCESS_KEY_ID_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "INTEGRATOR_AWS_SECRET_ACCESS_KEY_VAR=${INTEGRATOR_AWS_SECRET_ACCESS_KEY_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "INTEGRATOR_REPO=${INTEGRATOR_REPO}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "GIT_USER=${GIT_USER}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "GIT_EMAIL=${GIT_EMAIL}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${AUTOMATION_DATA_DIR}/context.properties

# All good
RESULT=0

