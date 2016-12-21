#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

RELEASE_MODE_CONTINUOUS="continuous"
RELEASE_MODE_SELECTIVE="selective"
RELEASE_MODE_PROMOTION="promotion"
RELEASE_MODE_HOTFIX="hotfix"
function usage() {
    echo -e "\nConfirm build references point to valid build images"
    echo -e "\nUsage: $(basename $0)"
    echo -e "\nwhere\n"
    echo -e "    -h shows this text"
    echo -e "\nDEFAULTS:\n"
    echo -e "\nNOTES:\n"
    echo -e "1. RELEASE_MODE is assumed to have been set via setContext"
    echo -e "2. ACCEPTANCE_TAG is assumed to have been set via setContext"
    echo -e ""
    exit
}

while getopts ":ho:" opt; do
    case $opt in
        h)
            usage
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

# Ensure mandatory arguments have been provided
if [[ (-z "${RELEASE_MODE}") ||
        (-z "${ACCEPTANCE_TAG}") ]]; then
    echo -e "\nInsufficient arguments"
    usage
fi

# Verify the build information
if [[ "${RELEASE_MODE}" == "${RELEASE_MODE_PROMOTION}" ]]; then

    # Get the from settings
    FROM_SETTINGS_DIR=${AUTOMATION_DATA_DIR}/${FROM_ACCOUNT}/config/${PRODUCT}/appsettings/${FROM_SEGMENT}
    if [[ ! -d ${FROM_SETTINGS_DIR} ]]; then
        # Settings not already there as a result of the segments sharing an account
        FROM_PRODUCT_DIR=${AUTOMATION_DATA_DIR}/${FROM_ACCOUNT}/from_config/${PRODUCT}
        mkdir -p ${FROM_PRODUCT_DIR}
        ${AUTOMATION_DIR}/manageRepo.sh -c -l "from product config" \
            -n "${FROM_PRODUCT_CONFIG_REPO}" -v "${FROM_PRODUCT_GIT_PROVIDER}" \
            -d "${FROM_PRODUCT_DIR}" -b "${ACCEPTANCE_TAG}"
        RESULT=$?
        if [[ "${RESULT}" -ne 0 ]]; then exit; fi
        FROM_SETTINGS_DIR=${FROM_PRODUCT_DIR}/appsettings/${FROM_SEGMENT}
    fi
            
    # Pull in the current build references in lower segment
    ${AUTOMATION_DIR}/manageBuildReferences.sh -f \
        -g ${FROM_SETTINGS_DIR}
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then exit; fi
fi

# Verify the reference updates
${AUTOMATION_DIR}/manageBuildReferences.sh -v ${ACCEPTANCE_TAG}
RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then exit; fi

# Include the build information in the detail message
${AUTOMATION_DIR}/manageBuildReferences.sh -l
RESULT=$?
