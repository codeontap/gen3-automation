#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

function usage() {
    echo -e "\nDetermine key settings for an tenant/account/product/segment" 
    echo -e "\nUsage: $(basename $0) -t TENANT -a ACCOUNT -p PRODUCT -c SEGMENT"
    echo -e "\nwhere\n"
    echo -e "(o) -a ACCOUNT is the tenant account name e.g. \"env01\""
    echo -e "(o) -c SEGMENT is the SEGMENT name e.g. \"production\""
    echo -e "    -h shows this text"
    echo -e "(o) -p PRODUCT is the product name e.g. \"eticket\""
    echo -e "(o) -t TENANT is the tenant name e.g. \"env\""
    echo -e "\nNOTES:\n"
    echo -e "1. The setting values are saved in context.properties in the current directory"
    echo -e ""
    exit
}

# Parse options
while getopts ":a:c:hp:t:" opt; do
    case $opt in
        a)
            ACCOUNT="${OPTARG}"
            ;;
        c)
            SEGMENT="${OPTARG}"
            ;;
        h)
            usage
            ;;
        p)
            PRODUCT="${OPTARG}"
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

# First things first - what automation provider are we?
AUTOMATION_BASE_DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )
if [[ -n "${JOB_NAME}" ]]; then
    AUTOMATION_PROVIDER="${AUTOMATION_PROVIDER:-jenkins}"
fi
AUTOMATION_PROVIDER="${AUTOMATION_PROVIDER,,}"
AUTOMATION_PROVIDER_UPPER="${AUTOMATION_PROVIDER^^}"
# AUTOMATION_PROVIDER_DIR="${AUTOMATION_BASE_DIR}/${AUTOMATION_PROVIDER}"
AUTOMATION_PROVIDER_DIR="${AUTOMATION_BASE_DIR}"

case ${AUTOMATION_PROVIDER} in
    jenkins)
        # Determine the integrator/tenant/product/environment/segment from 
        # the job name if not already defined or provided on the command line
        # Only parts of the jobname starting with "cot-" or "int-" are
        # considered and this prefix is removed to give the actual name.
        # "int-" denotes an integrator setup, while "cot-" denotes a tenant setup 
        JOB_PATH=($(echo "${JOB_NAME}" | tr "/" " "))
        INTEGRATOR_PARTS_ARRAY=()
        TENANT_PARTS_ARRAY=()
        INTEGRATOR_PREFIX="int-"
        TENANT_PREFIX="cot-"
        for PART in ${JOB_PATH[@]}; do
            if [[ "${PART}" =~ ^${INTEGRATOR_PREFIX}* ]]; then
                INTEGRATOR_PARTS_ARRAY+=("${PART#${INTEGRATOR_PREFIX}}")
            fi
            if [[ "${PART}" =~ ^${TENANT_PREFIX}* ]]; then
                TENANT_PARTS_ARRAY+=("${PART#${TENANT_PREFIX}}")
            fi
        done
        if [[ "${#INTEGRATOR_PARTS_ARRAY[@]}" -ne 0 ]]; then
            INTEGRATOR_PARTS_COUNT="${#INTEGRATOR_PARTS_ARRAY[@]}"

            if [[ "${INTEGRATOR_PARTS_COUNT}" -gt 4 ]]; then
                # integrator/tenant/product/environment/segment
                INTEGRATOR=${INTEGRATOR:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-5]}}
                TENANT=${TENANT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-4]}}
                PRODUCT=${PRODUCT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-3]}}
                ENVIRONMENT=${ENVIRONMENT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-2]}}
                SEGMENT=${SEGMENT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-1]}}
            fi
            if [[ "${INTEGRATOR_PARTS_COUNT}" -gt 3 ]]; then
                # tenant/product/environment/segment
                TENANT=${TENANT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-4]}}
                PRODUCT=${PRODUCT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-3]}}
                ENVIRONMENT=${ENVIRONMENT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-2]}}
                SEGMENT=${SEGMENT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-1]}}
            fi
            if [[ "${INTEGRATOR_PARTS_COUNT}" -gt 2 ]]; then
                # tenant/product/environment
                TENANT=${TENANT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-3]}}
                PRODUCT=${PRODUCT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-2]}}
                ENVIRONMENT=${ENVIRONMENT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-1]}}
            fi
            if [[ "${INTEGRATOR_PARTS_COUNT}" -gt 1 ]]; then
                # tenant/product
                TENANT=${TENANT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-2]}}
                PRODUCT=${PRODUCT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-1]}}
            fi
            if [[ "${INTEGRATOR_PARTS_COUNT}" -gt 0 ]]; then
                # product
                TENANT=${TENANT:-${INTEGRATOR_PARTS_ARRAY[${INTEGRATOR_PARTS_COUNT}-2]}}
            fi
        else
            TENANT_PARTS_COUNT="${#TENANT_PARTS_ARRAY[@]}"

            if [[ "${TENANT_PARTS_COUNT}" -gt 2 ]]; then
                # product/environment/segment
                PRODUCT=${PRODUCT:-${TENANT_PARTS_ARRAY[${TENANT_PARTS_COUNT}-3]}}
                ENVIRONMENT=${ENVIRONMENT:-${TENANT_PARTS_ARRAY[${TENANT_PARTS_COUNT}-2]}}
                SEGMENT=${SEGMENT:-${TENANT_PARTS_ARRAY[${TENANT_PARTS_COUNT}-1]}}
            fi
            if [[ "${TENANT_PARTS_COUNT}" -gt 1 ]]; then
                # product/environment
                PRODUCT=${PRODUCT:-${TENANT_PARTS_ARRAY[${TENANT_PARTS_COUNT}-2]}}
                ENVIRONMENT=${ENVIRONMENT:-${TENANT_PARTS_ARRAY[${TENANT_PARTS_COUNT}-1]}}
            fi
            if [[ "${TENANT_PARTS_COUNT}" -gt 0 ]]; then
                # product
                PRODUCT=${PRODUCT:-${TENANT_PARTS_ARRAY[${TENANT_PARTS_COUNT}-1]}}
            else
                # Default before use of folder plugin was for product to be first token in job name
                PRODUCT=${PRODUCT:-$(echo ${JOB_NAME} | cut -d '-' -f 1)}
            fi
        fi

        # Use the user info for git commits
        GIT_USER="${GIT_USER:-$BUILD_USER}"
        GIT_EMAIL="${GIT_EMAIL:-$BUILD_USER_EMAIL}"

        # Working directory
        AUTOMATION_DATA_DIR="${WORKSPACE}"
        ;;
esac

TENANT=${TENANT,,}
TENANT_UPPER=${TENANT^^}

PRODUCT=${PRODUCT,,}
PRODUCT_UPPER=${PRODUCT^^}

# Default SEGMENT and ENVIRONMENT - normally they are the same
SEGMENT=${SEGMENT:-${ENVIRONMENT}}
ENVIRONMENT=${ENVIRONMENT:-${SEGMENT}}

SEGMENT=${SEGMENT,,}
SEGMENT_UPPER=${SEGMENT^^}

# Determine the account from the product/segment combination
# if not already defined or provided on the command line
if [[ -z "${ACCOUNT}" ]]; then
    ACCOUNT_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_ACCOUNT"
    if [[ -z "${!ACCOUNT_VAR}" ]]; then
        ACCOUNT_VAR="${PRODUCT_UPPER}_ACCOUNT"
    fi
    ACCOUNT="${!ACCOUNT_VAR}"
fi

ACCOUNT=${ACCOUNT,,}
ACCOUNT_UPPER=${ACCOUNT^^}

# Default "GITHUB" git provider
GITHUB_DNS="${GITHUB_DNS:-github.com}"

# Default who to include as the author if git updates required
GIT_USER="${GIT_USER:-$GIT_USER_DEFAULT}"
GIT_USER="${GIT_USER:-alm}"
GIT_EMAIL="${GIT_EMAIL:-$GIT_EMAIL_DEFAULT}"

# Defaults for generation framework
# TODO: Add ability for ACCOUNT/PRODUCT override
GENERATION_GIT_DNS="${GENERATION_GIT_DNS:-github.com}"
GENERATION_GIT_ORG="${GENERATION_GIT_ORG:-codeontap}"
GENERATION_BIN_REPO="${GENERATION_BIN_REPO:-gsgen3.git}"
GENERATION_PATTERNS_REPO="${GENERATION_PATTERNS_REPO:-gsgen3-patterns.git}"
GENERATION_STARTUP_REPO="${GENERATION_STARTUP_REPO:-gsgen3-startup.git}"

# Determine the slice list and optional corresponding code tags and repos
# A slice can be followed by an optional code tag separated by an "!"
TAG_SEPARATOR='!'
SLICE_ARRAY=()
CODE_COMMIT_ARRAY=()
CODE_TAG_ARRAY=()
CODE_REPO_ARRAY=()
for CURRENT_SLICE in ${SLICES:-${SLICE}}; do
    SLICE_PART="${CURRENT_SLICE%%${TAG_SEPARATOR}*}"
    # Note that if there is no tag, then TAG_PART = SLICE_PART
    TAG_PART="${CURRENT_SLICE##*${TAG_SEPARATOR}}"
    COMMIT_PART="?"
    if [[ "${#SLICE_ARRAY[@]}" -eq 0 ]]; then
        # Processing the first slice
        if [[ -n "${CODE_TAG}" ]]; then
            # Permit separate commit/tag value - easier if only one repo involved
            TAG_PART="${CODE_TAG}"
            CURRENT_SLICE="${SLICE_PART}${TAG_SEPARATOR}${TAG_PART}"
        fi
    fi
        
    SLICE_ARRAY+=("${SLICE_PART,,}")

    if [[ (-n "${TAG_PART}") && ( "${CURRENT_SLICE}" =~ .+${TAG_SEPARATOR}.+ ) ]]; then
        if [[ "${#TAG_PART}" -eq 40 ]]; then
            # Assume its a full commit ids - at this stage we don't accept short commit ids
            COMMIT_PART="${TAG_PART}"
            TAG_PART="?"
        fi
    else
        TAG_PART="?"
    fi

    CODE_COMMIT_ARRAY+=("${COMMIT_PART,,}")
    CODE_TAG_ARRAY+=("${TAG_PART,,}")

    # Determine code repo for the slice - there may be none
    CODE_SLICE=$(echo "${SLICE_PART^^}" | tr "-" "_")
    PRODUCT_CODE_REPO_VAR="${PRODUCT_UPPER}_${CODE_SLICE^^}_CODE_REPO"
    if [[ -z "${!PRODUCT_CODE_REPO_VAR}" ]]; then
        PRODUCT_CODE_REPO_VAR="${PRODUCT_UPPER}_CODE_REPO"
    fi
    CODE_REPO="${!PRODUCT_CODE_REPO_VAR}"

    CODE_REPO_ARRAY+=("${CODE_REPO:-?}")
done

# Capture any provided git commit
case ${AUTOMATION_PROVIDER} in
    jenkins)
        if [[ -n "${GIT_COMMIT}" ]]; then
            CODE_COMMIT_ARRAY[0]="${GIT_COMMIT}"
        fi
        ;;
esac

# Regenerate the slice list in case the first code commit/tag was overriden
UPDATED_SLICES=
SLICE_SEPARATOR=""
for INDEX in $( seq 0 $((${#SLICE_ARRAY[@]}-1)) ); do
    UPDATED_SLICES="${UPDATED_SLICES}${SLICE_SEPARATOR}${SLICE_ARRAY[$INDEX]}"
    if [[ "${CODE_TAG_ARRAY[$INDEX]}" != "?" ]]; then
        UPDATED_SLICES="${UPDATED_SLICES}!${CODE_TAG_ARRAY[$INDEX]}"
    else
        if [[ "${CODE_COMMIT_ARRAY[$INDEX]}" != "?" ]]; then
            UPDATED_SLICES="${UPDATED_SLICES}!${CODE_COMMIT_ARRAY[$INDEX]}"
        fi
    fi
    SLICE_SEPARATOR=" "
done

# Determine the account provider
if [[ -z "${ACCOUNT_PROVIDER}" ]]; then
    ACCOUNT_PROVIDER_VAR="${ACCOUNT_UPPER}_ACCOUNT_PROVIDER"
    ACCOUNT_PROVIDER="${!ACCOUNT_PROVIDER_VAR}"
    ACCOUNT_PROVIDER="${ACCOUNT_PROVIDER:-aws}"
fi
ACCOUNT_PROVIDER="${ACCOUNT_PROVIDER,,}"
ACCOUNT_PROVIDER_UPPER="${ACCOUNT_PROVIDER^^}"
# AUTOMATION_DIR="${AUTOMATION_PROVIDER_DIR}/${ACCOUNT_PROVIDER}"
AUTOMATION_DIR="${AUTOMATION_PROVIDER_DIR}"

# Determine the account access credentials
case ${ACCOUNT_PROVIDER} in
    aws)
        . ${AUTOMATION_DIR}/setCredentials.sh ${ACCOUNT_UPPER}
        ;;
esac

# Determine the account git provider
if [[ -z "${ACCOUNT_GIT_PROVIDER}" ]]; then
    ACCOUNT_GIT_PROVIDER_VAR="${ACCOUNT_UPPER}_GIT_PROVIDER"
    ACCOUNT_GIT_PROVIDER="${!ACCOUNT_GIT_PROVIDER_VAR}"
    ACCOUNT_GIT_PROVIDER="${ACCOUNT_GIT_PROVIDER:-GITHUB}"
fi

ACCOUNT_GIT_PROVIDER=${ACCOUNT_GIT_PROVIDER,,}
ACCOUNT_GIT_PROVIDER_UPPER=${ACCOUNT_GIT_PROVIDER^^}

ACCOUNT_GIT_USER_VAR="${ACCOUNT_GIT_PROVIDER_UPPER}_USER"
ACCOUNT_GIT_PASSWORD_VAR="${ACCOUNT_GIT_PROVIDER_UPPER}_PASSWORD"
ACCOUNT_GIT_CREDENTIALS_VAR="${ACCOUNT_GIT_PROVIDER_UPPER}_CREDENTIALS"

ACCOUNT_GIT_ORG_VAR="${ACCOUNT_GIT_PROVIDER_UPPER}_ORG"
ACCOUNT_GIT_ORG="${!ACCOUNT_GIT_ORG_VAR}"

ACCOUNT_GIT_DNS_VAR="${ACCOUNT_GIT_PROVIDER_UPPER}_DNS"
ACCOUNT_GIT_DNS="${!ACCOUNT_GIT_DNS_VAR}"

ACCOUNT_GIT_API_DNS_VAR="${ACCOUNT_GIT_PROVIDER_UPPER}_API_DNS"
ACCOUNT_GIT_API_DNS="${!ACCOUNT_GIT_API_DNS_VAR:-api.$ACCOUNT_GIT_DNS}"

# Determine account repos
if [[ -z "${ACCOUNT_CONFIG_REPO}" ]]; then
    ACCOUNT_CONFIG_REPO_VAR="${ACCOUNT_UPPER}_CONFIG_REPO"
    ACCOUNT_CONFIG_REPO="${!ACCOUNT_CONFIG_REPO_VAR:-$ACCOUNT-config}"
fi
if [[ -z "${ACCOUNT_INFRASTRUCTURE_REPO}" ]]; then
    ACCOUNT_INFRASTRUCTURE_REPO_VAR="${ACCOUNT_UPPER}_INFRASTRUCTURE_REPO"
    ACCOUNT_INFRASTRUCTURE_REPO="${!ACCOUNT_INFRASTRUCTURE_REPO_VAR:-$ACCOUNT-infrastructure}"
fi

# Determine the product git provider
if [[ -z "${PRODUCT_GIT_PROVIDER}" ]]; then
    PRODUCT_GIT_PROVIDER_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_GIT_PROVIDER"
    if [[ -z "${!PRODUCT_GIT_PROVIDER_VAR}" ]]; then
        PRODUCT_GIT_PROVIDER_VAR="${PRODUCT_UPPER}_GIT_PROVIDER"
    fi
    PRODUCT_GIT_PROVIDER="${!PRODUCT_GIT_PROVIDER_VAR}"
    PRODUCT_GIT_PROVIDER="${PRODUCT_GIT_PROVIDER:-$ACCOUNT_GIT_PROVIDER}"
fi

PRODUCT_GIT_PROVIDER=${PRODUCT_GIT_PROVIDER,,}
PRODUCT_GIT_PROVIDER_UPPER=${PRODUCT_GIT_PROVIDER^^}

PRODUCT_GIT_USER_VAR="${PRODUCT_GIT_PROVIDER_UPPER}_USER"
PRODUCT_GIT_PASSWORD_VAR="${PRODUCT_GIT_PROVIDER_UPPER}_PASSWORD"
PRODUCT_GIT_CREDENTIALS_VAR="${PRODUCT_GIT_PROVIDER_UPPER}_CREDENTIALS"

PRODUCT_GIT_ORG_VAR="${PRODUCT_GIT_PROVIDER_UPPER}_ORG"
PRODUCT_GIT_ORG="${!PRODUCT_GIT_ORG_VAR}"

PRODUCT_GIT_DNS_VAR="${PRODUCT_GIT_PROVIDER_UPPER}_DNS"
PRODUCT_GIT_DNS="${!PRODUCT_GIT_DNS_VAR}"

PRODUCT_GIT_API_DNS_VAR="${PRODUCT_GIT_PROVIDER_UPPER}_API_DNS"
PRODUCT_GIT_API_DNS="${!PRODUCT_GIT_API_DNS_VAR:-api.$PRODUCT_GIT_DNS}"

# Determine the product local docker provider
if [[ -z "${PRODUCT_DOCKER_PROVIDER}" ]]; then
    PRODUCT_DOCKER_PROVIDER_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_DOCKER_PROVIDER"
    if [[ -z "${!PRODUCT_DOCKER_PROVIDER_VAR}" ]]; then
        PRODUCT_DOCKER_PROVIDER_VAR="${PRODUCT_UPPER}_DOCKER_PROVIDER"
    fi
    PRODUCT_DOCKER_PROVIDER="${!PRODUCT_DOCKER_PROVIDER_VAR}"
    PRODUCT_DOCKER_PROVIDER="${PRODUCT_DOCKER_PROVIDER:-$ACCOUNT}"
fi

PRODUCT_DOCKER_PROVIDER=${PRODUCT_DOCKER_PROVIDER,,}
PRODUCT_DOCKER_PROVIDER_UPPER=${PRODUCT_DOCKER_PROVIDER^^}

PRODUCT_DOCKER_USER_VAR="${PRODUCT_DOCKER_PROVIDER_UPPER}_USER"
PRODUCT_DOCKER_PASSWORD_VAR="${PRODUCT_DOCKER_PROVIDER_UPPER}_PASSWORD"

PRODUCT_DOCKER_DNS_VAR="${PRODUCT_DOCKER_PROVIDER_UPPER}_DNS"
PRODUCT_DOCKER_DNS="${!PRODUCT_DOCKER_DNS_VAR}"

PRODUCT_DOCKER_API_DNS_VAR="${PRODUCT_DOCKER_PROVIDER_UPPER}_API_DNS"
PRODUCT_DOCKER_API_DNS="${!PRODUCT_DOCKER_API_DNS_VAR:-$PRODUCT_DOCKER_DNS}"

# Determine the product remote docker provider (for sourcing new images)
if [[ -z "${PRODUCT_REMOTE_DOCKER_PROVIDER}" ]]; then
    PRODUCT_REMOTE_DOCKER_PROVIDER_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_REMOTE_DOCKER_PROVIDER"
    if [[ -z "${!PRODUCT_REMOTE_DOCKER_PROVIDER_VAR}" ]]; then
        PRODUCT_REMOTE_DOCKER_PROVIDER_VAR="${PRODUCT_UPPER}_REMOTE_DOCKER_PROVIDER"
    fi
    PRODUCT_REMOTE_DOCKER_PROVIDER="${!PRODUCT_REMOTE_DOCKER_PROVIDER_VAR}"
    PRODUCT_REMOTE_DOCKER_PROVIDER="${PRODUCT_REMOTE_DOCKER_PROVIDER:-$PRODUCT_DOCKER_PROVIDER}"
fi

PRODUCT_REMOTE_DOCKER_PROVIDER=${PRODUCT_REMOTE_DOCKER_PROVIDER,,}
PRODUCT_REMOTE_DOCKER_PROVIDER_UPPER=${PRODUCT_REMOTE_DOCKER_PROVIDER^^}

PRODUCT_REMOTE_DOCKER_USER_VAR="${PRODUCT_REMOTE_DOCKER_PROVIDER_UPPER}_USER"
PRODUCT_REMOTE_DOCKER_PASSWORD_VAR="${PRODUCT_REMOTE_DOCKER_PROVIDER_UPPER}_PASSWORD"

PRODUCT_REMOTE_DOCKER_DNS_VAR="${PRODUCT_REMOTE_DOCKER_PROVIDER_UPPER}_DNS"
PRODUCT_REMOTE_DOCKER_DNS="${!PRODUCT_REMOTE_DOCKER_DNS_VAR}"

PRODUCT_REMOTE_DOCKER_API_DNS_VAR="${PRODUCT_REMOTE_DOCKER_PROVIDER_UPPER}_API_DNS"
PRODUCT_REMOTE_DOCKER_API_DNS="${!PRODUCT_REMOTE_DOCKER_API_DNS_VAR:-$PRODUCT_REMOTE_DOCKER_DNS}"

# Determine the suffix to add to verification identifiers to form the remote tag
# used when sourcing new images
if [[ -z "${PRODUCT_REMOTE_DOCKER_TAG_SUFFIX}" ]]; then
    PRODUCT_REMOTE_DOCKER_TAG_SUFFIX_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_REMOTE_DOCKER_TAG_SUFFIX"
    if [[ -z "${!PRODUCT_REMOTE_DOCKER_TAG_SUFFIX_VAR}" ]]; then
        PRODUCT_REMOTE_DOCKER_TAG_SUFFIX_VAR="${PRODUCT_UPPER}_REMOTE_DOCKER_TAG_SUFFIX"
    fi
    PRODUCT_REMOTE_DOCKER_TAG_SUFFIX="${!PRODUCT_REMOTE_DOCKER_TAG_SUFFIX_VAR}"
fi

# Determine product repos
if [[ -z "${PRODUCT_CONFIG_REPO}" ]]; then
    PRODUCT_CONFIG_REPO_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_CONFIG_REPO"
    if [[ -z "${!PRODUCT_CONFIG_REPO_VAR}" ]]; then
        PRODUCT_CONFIG_REPO_VAR="${PRODUCT_UPPER}_CONFIG_REPO"
    fi
    PRODUCT_CONFIG_REPO="${!PRODUCT_CONFIG_REPO_VAR:-$PRODUCT-config}"
fi
if [[ -z "${PRODUCT_INFRASTRUCTURE_REPO}" ]]; then
    PRODUCT_INFRASTRUCTURE_REPO_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_INFRASTRUCTURE_REPO"
    if [[ -z "${!PRODUCT_INFRASTRUCTURE_REPO_VAR}" ]]; then
        PRODUCT_INFRASTRUCTURE_REPO_VAR="${PRODUCT_UPPER}_INFRASTRUCTURE_REPO"
    fi
    PRODUCT_INFRASTRUCTURE_REPO="${!PRODUCT_INFRASTRUCTURE_REPO_VAR:-$PRODUCT-infrastructure}"
fi

# Determine the product code git provider
if [[ -z "${PRODUCT_CODE_GIT_PROVIDER}" ]]; then
    PRODUCT_CODE_GIT_PROVIDER_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_GIT_PROVIDER"
    if [[ -z "${!PRODUCT_CODE_GIT_PROVIDER_VAR}" ]]; then
        PRODUCT_CODE_GIT_PROVIDER_VAR="${PRODUCT_UPPER}_GIT_PROVIDER"
    fi
    PRODUCT_CODE_GIT_PROVIDER="${!PRODUCT_CODE_GIT_PROVIDER_VAR}"
    PRODUCT_CODE_GIT_PROVIDER="${PRODUCT_CODE_GIT_PROVIDER:-$PRODUCT_GIT_PROVIDER}"
fi

PRODUCT_CODE_GIT_PROVIDER=${PRODUCT_CODE_GIT_PROVIDER,,}
PRODUCT_CODE_GIT_PROVIDER_UPPER=${PRODUCT_CODE_GIT_PROVIDER^^}

PRODUCT_CODE_GIT_USER_VAR="${PRODUCT_CODE_GIT_PROVIDER_UPPER}_USER"
PRODUCT_CODE_GIT_PASSWORD_VAR="${PRODUCT_CODE_GIT_PROVIDER_UPPER}_PASSWORD"
PRODUCT_CODE_GIT_CREDENTIALS_VAR="${PRODUCT_CODE_GIT_PROVIDER_UPPER}_CREDENTIALS"

PRODUCT_CODE_GIT_ORG_VAR="${PRODUCT_CODE_GIT_PROVIDER_UPPER}_ORG"
PRODUCT_CODE_GIT_ORG="${!PRODUCT_CODE_GIT_ORG_VAR}"

PRODUCT_CODE_GIT_DNS_VAR="${PRODUCT_CODE_GIT_PROVIDER_UPPER}_DNS"
PRODUCT_CODE_GIT_DNS="${!PRODUCT_CODE_GIT_DNS_VAR}"

PRODUCT_CODE_GIT_API_DNS_VAR="${PRODUCT_CODE_GIT_PROVIDER_UPPER}_API_DNS"
PRODUCT_CODE_GIT_API_DNS="${!PRODUCT_CODE_GIT_API_DNS_VAR:-api.$PRODUCT_CODE_GIT_DNS}"

# Determine the release and verification tag
RELEASE_TAG="r${BUILD_NUMBER}-${SEGMENT}"
if [[ -n "${RELEASE_IDENTIFIER}" ]]; then
    RELEASE_TAG="${RELEASE_IDENTIFIER}-${SEGMENT}"
    if [[ "${RELEASE_IDENTIFIER}" =~ ^-?[0-9]+$ ]]; then
        # It is a number - assume identifier defaulted to build number
        # Note that this won't work is user decides to use their own
        # integer based scheme. Advise is thus to add a non-numeric prefix/suffix
        # as long as its not a prefix of "r"
        RELEASE_TAG="r${RELEASE_TAG}"
    fi
fi

if [[ -n "${VERIFICATION_IDENTIFIER}" ]]; then
    VERIFICATION_TAG="${VERIFICATION_IDENTIFIER}${PRODUCT_REMOTE_DOCKER_TAG_SUFFIX}"
    if [[ "${VERIFICATION_IDENTIFIER}" =~ ^-?[0-9]+$ ]]; then
        # It is a number - assume identifier defaulted to build number
        # Note that this won't work is user decides to use their own
        # integer based scheme. Advise is thus to add a non-numeric prefix/suffix
        # as long as its not a prefix of "r"
        VERIFICATION_TAG="r${VERIFICATION_TAG}"
    fi
fi

# Basic details for git commits/slack notification (enhanced by other scripts)
DETAIL_MESSAGE="product=${PRODUCT}"
if [[ -n "${ENVIRONMENT}" ]];               then DETAIL_MESSAGE="${DETAIL_MESSAGE}, environment=${ENVIRONMENT}"; fi
if [[ "${SEGMENT}" != "${ENVIRONMENT}" ]];  then DETAIL_MESSAGE="${DETAIL_MESSAGE}, segment=${SEGMENT}"; fi
if [[ -n "${TIER}" ]];                      then DETAIL_MESSAGE="${DETAIL_MESSAGE}, tier=${TIER}"; fi
if [[ -n "${COMPONENT}" ]];                 then DETAIL_MESSAGE="${DETAIL_MESSAGE}, component=${COMPONENT}"; fi
if [[ "${#SLICE_ARRAY[@]}" -ne 0 ]];        then DETAIL_MESSAGE="${DETAIL_MESSAGE}, slices=${UPDATED_SLICES}"; fi
if [[ -n "${TASK}" ]];                      then DETAIL_MESSAGE="${DETAIL_MESSAGE}, task=${TASK}"; fi
if [[ -n "${TASKS}" ]];                     then DETAIL_MESSAGE="${DETAIL_MESSAGE}, tasks=${TASKS}"; fi
if [[ -n "${GIT_USER}" ]];                  then DETAIL_MESSAGE="${DETAIL_MESSAGE}, user=${GIT_USER}"; fi
if [[ -n "${MODE}" ]];                      then DETAIL_MESSAGE="${DETAIL_MESSAGE}, mode=${MODE}"; fi

# Save for future steps
echo "TENANT=${TENANT}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "ACCOUNT=${ACCOUNT}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT=${PRODUCT}" >> ${AUTOMATION_DATA_DIR}/context.properties
if [[ -n "${SEGMENT}" ]]; then echo "SEGMENT=${SEGMENT}" >> ${AUTOMATION_DATA_DIR}/context.properties; fi
if [[ -n "${UPDATED_SLICES}" ]]; then echo "SLICES=${UPDATED_SLICES}" >> ${AUTOMATION_DATA_DIR}/context.properties; fi

echo "GIT_USER=${GIT_USER}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "GIT_EMAIL=${GIT_EMAIL}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "GENERATION_GIT_DNS=${GENERATION_GIT_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "GENERATION_GIT_ORG=${GENERATION_GIT_ORG}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "GENERATION_BIN_REPO=${GENERATION_BIN_REPO}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "GENERATION_PATTERNS_REPO=${GENERATION_PATTERNS_REPO}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "GENERATION_STARTUP_REPO=${GENERATION_STARTUP_REPO}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "SLICE_LIST=${SLICE_ARRAY[@]}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "CODE_COMMIT_LIST=${CODE_COMMIT_ARRAY[@]}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "CODE_TAG_LIST=${CODE_TAG_ARRAY[@]}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "CODE_REPO_LIST=${CODE_REPO_ARRAY[@]}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "ACCOUNT_PROVIDER=${ACCOUNT_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "ACCOUNT_GIT_PROVIDER=${ACCOUNT_GIT_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "ACCOUNT_GIT_USER_VAR=${ACCOUNT_GIT_USER_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "ACCOUNT_GIT_PASSWORD_VAR=${ACCOUNT_GIT_PASSWORD_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "ACCOUNT_GIT_CREDENTIALS_VAR=${ACCOUNT_GIT_CREDENTIALS_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "ACCOUNT_GIT_ORG=${ACCOUNT_GIT_ORG}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "ACCOUNT_GIT_DNS=${ACCOUNT_GIT_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "ACCOUNT_GIT_API_DNS=${ACCOUNT_GIT_API_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "ACCOUNT_CONFIG_REPO=${ACCOUNT_CONFIG_REPO}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "ACCOUNT_INFRASTRUCTURE_REPO=${ACCOUNT_INFRASTRUCTURE_REPO}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "PRODUCT_GIT_PROVIDER=${PRODUCT_GIT_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_GIT_USER_VAR=${PRODUCT_GIT_USER_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_GIT_PASSWORD_VAR=${PRODUCT_GIT_PASSWORD_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_GIT_CREDENTIALS_VAR=${PRODUCT_GIT_CREDENTIALS_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_GIT_ORG=${PRODUCT_GIT_ORG}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_GIT_DNS=${PRODUCT_GIT_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_GIT_API_DNS=${PRODUCT_GIT_API_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "PRODUCT_DOCKER_PROVIDER=${PRODUCT_DOCKER_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_DOCKER_USER_VAR=${PRODUCT_DOCKER_USER_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_DOCKER_PASSWORD_VAR=${PRODUCT_DOCKER_PASSWORD_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_DOCKER_DNS=${PRODUCT_DOCKER_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_DOCKER_API_DNS=${PRODUCT_DOCKER_API_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "PRODUCT_REMOTE_DOCKER_PROVIDER=${PRODUCT_REMOTE_DOCKER_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_REMOTE_DOCKER_USER_VAR=${PRODUCT_REMOTE_DOCKER_USER_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_REMOTE_DOCKER_PASSWORD_VAR=${PRODUCT_REMOTE_DOCKER_PASSWORD_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_REMOTE_DOCKER_DNS=${PRODUCT_REMOTE_DOCKER_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_REMOTE_DOCKER_API_DNS=${PRODUCT_REMOTE_DOCKER_API_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "PRODUCT_CONFIG_REPO=${PRODUCT_CONFIG_REPO}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_INFRASTRUCTURE_REPO=${PRODUCT_INFRASTRUCTURE_REPO}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "PRODUCT_CODE_GIT_PROVIDER=${PRODUCT_CODE_GIT_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_CODE_GIT_USER_VAR=${PRODUCT_CODE_GIT_USER_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_CODE_GIT_PASSWORD_VAR=${PRODUCT_CODE_GIT_PASSWORD_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_CODE_GIT_CREDENTIALS_VAR=${PRODUCT_CODE_GIT_CREDENTIALS_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_CODE_GIT_ORG=${PRODUCT_CODE_GIT_ORG}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_CODE_GIT_DNS=${PRODUCT_CODE_GIT_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "PRODUCT_CODE_GIT_API_DNS=${PRODUCT_CODE_GIT_API_DNS}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "RELEASE_TAG=${RELEASE_TAG}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "VERIFICATION_TAG=${VERIFICATION_TAG}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${AUTOMATION_DATA_DIR}/context.properties

echo "AUTOMATION_BASE_DIR=${AUTOMATION_BASE_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "AUTOMATION_PROVIDER=${AUTOMATION_PROVIDER}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "AUTOMATION_PROVIDER_DIR=${AUTOMATION_PROVIDER_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "AUTOMATION_DIR=${AUTOMATION_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties
echo "AUTOMATION_DATA_DIR=${AUTOMATION_DATA_DIR}" >> ${AUTOMATION_DATA_DIR}/context.properties

case ${ACCOUNT_PROVIDER} in
    aws)
        echo "ACCOUNT_AWS_ACCESS_KEY_ID_VAR=${AWS_CRED_AWS_ACCESS_KEY_ID_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
        echo "ACCOUNT_AWS_SECRET_ACCESS_KEY_VAR=${AWS_CRED_AWS_SECRET_ACCESS_KEY_VAR}" >> ${AUTOMATION_DATA_DIR}/context.properties
        echo "ACCOUNT_TEMP_AWS_ACCESS_KEY_ID=${AWS_CRED_TEMP_AWS_ACCESS_KEY_ID}" >> ${AUTOMATION_DATA_DIR}/context.properties
        echo "ACCOUNT_TEMP_AWS_SECRET_ACCESS_KEY=${AWS_CRED_TEMP_AWS_SECRET_ACCESS_KEY}" >> ${AUTOMATION_DATA_DIR}/context.properties
        echo "ACCOUNT_TEMP_AWS_SESSION_TOKEN=${AWS_CRED_TEMP_AWS_SESSION_TOKEN}" >> ${AUTOMATION_DATA_DIR}/context.properties
        ;;
esac

# All good
RESULT=0

