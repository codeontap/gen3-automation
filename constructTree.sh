#!/usr/bin/env bash

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
[[ -z "${ACCOUNT}" ]] && fatal "ACCOUNT not defined" && exit

# Save for later steps
save_context_property PRODUCT_CONFIG_REFERENCE "${PRODUCT_CONFIG_REFERENCE}"
save_context_property PRODUCT_INFRASTRUCTURE_REFERENCE "${PRODUCT_INFRASTRUCTURE_REFERENCE}"

# Record what is happening
info "Creating the context directory tree"

# Define the top level directory representing the account
BASE_DIR="${AUTOMATION_DATA_DIR}/${ACCOUNT}"
mkdir -p "${BASE_DIR}"
touch ${BASE_DIR}/root.json

# Pull repos into a temporary directory so the contents can be examined
BASE_DIR_TEMP="${BASE_DIR}/temp"

if [[ !("${EXCLUDE_PRODUCT_DIRECTORIES}" == "true") ]]; then

    # Pull in the product config repo
    ${AUTOMATION_DIR}/manageRepo.sh -c -l "product config" \
        -n "${PRODUCT_CONFIG_REPO}" -v "${PRODUCT_GIT_PROVIDER}" \
        -d "${BASE_DIR_TEMP}" -b "${PRODUCT_CONFIG_REFERENCE}"
    RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

    # Ensure temporary files are ignored
    [[ (! -f "${BASE_DIR_TEMP}/.gitignore") || ($(grep -q "temp_\*" "${BASE_DIR_TEMP}/.gitignore") -ne 0) ]] && \
      echo "temp_*" >> "${BASE_DIR_TEMP}/.gitignore"

    # The config repo may contain
    # - config +/- infrastructure
    # - product(s) +/- account(s)
    if [[ -n $(findDir "${BASE_DIR_TEMP}" "infrastructure") ]]; then
        # Mix of infrastructure and config
        if [[ -n $(findDir "${BASE_DIR_TEMP}" "${ACCOUNT}") ]]; then
            # Everything in one repo
            PRODUCT_CONFIG_DIR="${BASE_DIR}/cmdb"
        else
            if [[ -n $(findDir "${BASE_DIR_TEMP}" "${PRODUCT}") ]]; then
                # Multi-product repo
                PRODUCT_CONFIG_DIR="${BASE_DIR}/products"
            else
                # Single product repo
                PRODUCT_CONFIG_DIR="${BASE_DIR}/${PRODUCT}"
            fi
        fi
    else
        # Just config
        if [[ -n $(findDir "${BASE_DIR_TEMP}" "${ACCOUNT}") ]]; then
            # products and accounts
            PRODUCT_CONFIG_DIR="${BASE_DIR}/config"
        else
            if [[ -n $(findDir "${BASE_DIR_TEMP}" "${PRODUCT}") ]]; then
                # Multi-product repo
                PRODUCT_CONFIG_DIR="${BASE_DIR}/config/products"
            else
                # Single product repo
                PRODUCT_CONFIG_DIR="${BASE_DIR}/config/${PRODUCT}"
            fi
        fi
    fi

    mkdir -p $(filePath "${PRODUCT_CONFIG_DIR}")
    mv "${BASE_DIR_TEMP}" "${PRODUCT_CONFIG_DIR}"
    save_context_property PRODUCT_CONFIG_COMMIT "$(git -C "${PRODUCT_CONFIG_DIR}" rev-parse HEAD)"

    PRODUCT_INFRASTRUCTURE_DIR=$(findGen3ProductInfrastructureDir "${BASE_DIR}" "${PRODUCT}")
    if [[ -z "${PRODUCT_INFRASTRUCTURE_DIR}" ]]; then
        # Pull in the infrastructure repo
        ${AUTOMATION_DIR}/manageRepo.sh -c -l "product infrastructure" \
            -n "${PRODUCT_INFRASTRUCTURE_REPO}" -v "${PRODUCT_GIT_PROVIDER}" \
            -d "${BASE_DIR_TEMP}" -b "${PRODUCT_INFRASTRUCTURE_REFERENCE}"
        RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

        # Ensure temporary files are ignored
        [[ (! -f "${BASE_DIR_TEMP}/.gitignore") || ($(grep -q "temp_\*" "${BASE_DIR_TEMP}/.gitignore") -ne 0) ]] && \
          echo "temp_*" >> "${BASE_DIR_TEMP}/.gitignore"

        if [[ -n $(findDir "${BASE_DIR_TEMP}" "${ACCOUNT}") ]]; then
            # products and accounts
            PRODUCT_INFRASTRUCTURE_DIR="${BASE_DIR}/infrastructure"
        else
            if [[ -n $(findDir "${BASE_DIR_TEMP}" "${PRODUCT}") ]]; then
                # Multi-product repo
                PRODUCT_INFRASTRUCTURE_DIR="${BASE_DIR}/infrastructure/products"
            else
                # Single product repo
                PRODUCT_INFRASTRUCTURE_DIR="${BASE_DIR}/infrastructure/${PRODUCT}"
            fi
        fi
        mkdir -p $(filePath "${PRODUCT_INFRASTRUCTURE_DIR}")
        mv "${BASE_DIR_TEMP}" "${PRODUCT_INFRASTRUCTURE_DIR}"
    fi

    save_context_property PRODUCT_INFRASTRUCTURE_COMMIT "$(git -C "${PRODUCT_INFRASTRUCTURE_DIR}" rev-parse HEAD)"
fi

if [[ !("${EXCLUDE_ACCOUNT_DIRECTORIES}" == "true") ]]; then

    # Pull in the account config repo
    ACCOUNT_CONFIG_DIR=$(findGen3AccountDir "${BASE_DIR}" "${ACCOUNT}")
    if [[ -z "${ACCOUNT_CONFIG_DIR}" ]]; then
        ${AUTOMATION_DIR}/manageRepo.sh -c -l "account config" \
            -n "${ACCOUNT_CONFIG_REPO}" -v "${ACCOUNT_GIT_PROVIDER}" \
            -d "${BASE_DIR_TEMP}"
        RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

        # Ensure temporary files are ignored
        [[ (! -f "${BASE_DIR_TEMP}/.gitignore") || ($(grep -q "temp_\*" "${BASE_DIR_TEMP}/.gitignore") -ne 0) ]] && \
          echo "temp_*" >> "${BASE_DIR_TEMP}/.gitignore"

        if [[ -n $(findDir "${BASE_DIR_TEMP}" "infrastructure") ]]; then
            # Mix of infrastructure and config
            if [[ -n $(findDir "${BASE_DIR_TEMP}" "${ACCOUNT}") ]]; then
                # Multi-account repo
                ACCOUNT_CONFIG_DIR="${BASE_DIR}/accounts"
            else
                # Single account repo
                ACCOUNT_CONFIG_DIR="${BASE_DIR}/${ACCOUNT}"
            fi
        else
            if [[ -n $(findDir "${BASE_DIR_TEMP}" "${ACCOUNT}") ]]; then
                # Multi-account repo
                ACCOUNT_CONFIG_DIR="${BASE_DIR}/config/accounts"
            else
                # Single account repo
                ACCOUNT_CONFIG_DIR="${BASE_DIR}/config/${ACCOUNT}"
            fi
        fi
        mkdir -p $(filePath "${ACCOUNT_CONFIG_DIR}")
        mv "${BASE_DIR_TEMP}" "${ACCOUNT_CONFIG_DIR}"
    fi

    ACCOUNT_INFRASTRUCTURE_DIR=$(findGen3AccountInfrastructureDir "${BASE_DIR}" "${ACCOUNT}")
    if [[ -z "${ACCOUNT_INFRASTRUCTURE_DIR}" ]]; then
        # Pull in the account infrastructure repo
        ${AUTOMATION_DIR}/manageRepo.sh -c -l "account infrastructure" \
            -n "${ACCOUNT_INFRASTRUCTURE_REPO}" -v "${ACCOUNT_GIT_PROVIDER}" \
            -d "${BASE_DIR_TEMP}"
        RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

        # Ensure temporary files are ignored
        [[ (! -f "${BASE_DIR_TEMP}/.gitignore") || ($(grep -q "temp_\*" "${BASE_DIR_TEMP}/.gitignore") -ne 0) ]] && \
          echo "temp_*" >> "${BASE_DIR_TEMP}/.gitignore"

        if [[ -n $(findDir "${BASE_DIR_TEMP}" "${ACCOUNT}") ]]; then
            # Multi-account repo
            ACCOUNT_INFRASTRUCTURE_DIR="${BASE_DIR}/infrastructure/accounts"
        else
            # Single account repo
            ACCOUNT_INFRASTRUCTURE_DIR="${BASE_DIR}/infrastructure/${ACCOUNT}"
        fi
        mkdir -p $(filePath "${ACCOUNT_INFRASTRUCTURE_DIR}")
        mv "${BASE_DIR_TEMP}" "${ACCOUNT_INFRASTRUCTURE_DIR}"
    fi

# TODO(mfl): 03/02/2020 Remove the following code once its confirmed its redundant
# From the Jenkins logs it throws errors when TENANT is non-empty which makes sense
# as BASE_DIR_TEMP has been cleared by processing of the ACCOUNT. However sometimes
# it doesn't which suggests that it either is blank or contains a directory with an
# infrastructure subdirectory.
# Either way, without a temp dir to move, it seems unnecessary.
#    TENANT_INFRASTRUCTURE_DIR=$(findGen3TenantInfrastructureDir "${BASE_DIR}" "${TENANT}")
#    if [[ -z "${TENANT_INFRASTRUCTURE_DIR}" ]]; then
#
#        TENANT_INFRASTRUCTURE_DIR="${BASE_DIR}/${TENANT}"
#        mkdir -p $(filePath "${TENANT_INFRASTRUCTURE_DIR}")
#        mv "${BASE_DIR_TEMP}" "${TENANT_INFRASTRUCTURE_DIR}"
#    fi

fi

# Pull in the default generation repo if not overridden by product or locally installed
if [[ -z "${GENERATION_DIR}" ]]; then
    if [[ -z "${GENERATION_BASE_DIR}" ]]; then
        GENERATION_BASE_DIR="${BASE_DIR}/bin"
        PRODUCT_GENERATION_BASE_DIR="$(findDir "${BASE_DIR}" "${PRODUCT}/bin" )"
        if [[ -n "${PRODUCT_GENERATION_BASE_DIR}" ]]; then
            mkdir -p "${GENERATION_BASE_DIR}"
            cp -rp "${PRODUCT_GENERATION_BASE_DIR}" "${GENERATION_BASE_DIR}"
        else
            ${AUTOMATION_DIR}/manageRepo.sh -c -l "generation bin" \
                -n "${GENERATION_BIN_REPO}" -v "${GENERATION_GIT_PROVIDER}" \
                -d "${GENERATION_BASE_DIR}" -b "${GENERATION_BIN_REFERENCE}"
            RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit
        fi
    fi
    save_context_property GENERATION_DIR "${GENERATION_BASE_DIR}/${ACCOUNT_PROVIDER}"
fi

# Pull in the patterns repo if not overridden by product or locally installed
if [[ -z "${GENERATION_PATTERNS_DIR}" ]]; then
    if [[ "${INCLUDE_ALL_REPOS}" == "true" ]]; then
        GENERATION_PATTERNS_DIR="${BASE_DIR}/patterns"
        PRODUCT_GENERATION_PATTERNS_DIR="$(findDir "${BASE_DIR}" "${PRODUCT}/patterns" )"
        if [[ -n "${PRODUCT_GENERATION_PATTERNS_DIR}" ]]; then
            mkdir -p "${GENERATION_PATTERNS_DIR}"
            cp -rp "${PRODUCT_GENERATION_PATTERNS_DIR}" "${GENERATION_PATTERNS_DIR}"
        else
            ${AUTOMATION_DIR}/manageRepo.sh -c -l "generation patterns" \
                -n "${GENERATION_PATTERNS_REPO}" -v "${GENERATION_GIT_PROVIDER}" \
                -d "${GENERATION_PATTERNS_DIR}" -b "${GENERATION_PATTERNS_REFERENCE}"
            RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit
        fi
        save_context_property GENERATION_PATTERNS_DIR "${GENERATION_PATTERNS_DIR}/${ACCOUNT_PROVIDER}"
    fi
fi


# Pull in the default generation startup repo if not overridden by product or locally installed
if [[ -z "${GENERATION_STARTUP_DIR}" ]]; then
    if [[ "${INCLUDE_ALL_REPOS}" == "true" ]]; then
        GENERATION_STARTUP_DIR="${BASE_DIR}/startup"
        PRODUCT_GENERATION_STARTUP_DIR="$(findDir "${BASE_DIR}" "${PRODUCT}/startup" )"
        if [[ -n "${PRODUCT_GENERATION_STARTUP_DIR}" ]]; then
            mkdir -p "${GENERATION_STARTUP_DIR}"
            cp -rp "${PRODUCT_GENERATION_STARTUP_DIR}" "${GENERATION_STARTUP_DIR}"
        else
            ${AUTOMATION_DIR}/manageRepo.sh -c -l "generation startup" \
                -n "${GENERATION_STARTUP_REPO}" -v "${GENERATION_GIT_PROVIDER}" \
                -d "${GENERATION_STARTUP_DIR}" -b "${GENERATION_STARTUP_REFERENCE}"
            RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit
        fi
        save_context_property GENERATION_STARTUP_DIR "${GENERATION_STARTUP_DIR}"
    fi
fi

# Examine the structure and define key directories

findGen3Dirs "${BASE_DIR}"
RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

# A couple of the older upgrades need GENERATION_DATA_DIR set to
# locate the AWS account number to account id mappings
export GENERATION_DATA_DIR="${BASE_DIR}"

# Check the cmdb doesn't need upgrading
debug "Checking if cmdb upgrade needed ..."
upgrade_cmdb "${BASE_DIR}" ||
    { RESULT=$?; fatal "CMDB upgrade failed."; exit; }

# Remember directories for future steps
save_gen3_dirs_in_context

