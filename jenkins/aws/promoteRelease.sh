#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

RELEASE_MODE_PROMOTION="promotion"

# Ensure mandatory arguments have been provided
if [[ (-z "${RELEASE_MODE}") ||
        (-z "${ACCEPTANCE_TAG}") ]]; then
    echo -e "\nInsufficient arguments" >&2
    exit
fi

# Verify the build information
if [[ "${RELEASE_MODE}" == "${RELEASE_MODE_PROMOTION}" ]]; then

    # Get the from settings in a separate dir - name it differently
    # in case both segments in the same repo
    FROM_PRODUCT_DIR=${AUTOMATION_DATA_DIR}/${FROM_ACCOUNT}/from_config/${PRODUCT}
    mkdir -p ${FROM_PRODUCT_DIR}
    ${AUTOMATION_DIR}/manageRepo.sh -c -l "from product config" \
        -n "${FROM_PRODUCT_CONFIG_REPO}" -v "${FROM_PRODUCT_GIT_PROVIDER}" \
        -d "${FROM_PRODUCT_DIR}" -b "${ACCEPTANCE_TAG}"
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then exit; fi
    FROM_SETTINGS_DIR=${FROM_PRODUCT_DIR}/appsettings/${FROM_SEGMENT}
            
    # Pull in the current build references in lower segment
    ${AUTOMATION_DIR}/manageBuildReferences.sh -f \
        -g ${FROM_SETTINGS_DIR}
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then exit; fi
fi

# All good
RESULT=0