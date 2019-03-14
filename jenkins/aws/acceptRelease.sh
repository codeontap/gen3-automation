#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Ensure mandatory arguments have been provided
[[ (-z "${RELEASE_MODE}") ||
    (-z "${RELEASE_TAG}") ]] && fatalMandatory

# Include the build information in the detail message
${AUTOMATION_DIR}/manageBuildReferences.sh -l
RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit

# Tag the builds
${AUTOMATION_DIR}/manageBuildReferences.sh -a "${RELEASE_TAG}"
RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit

# Verify the build information
if [[ "${RELEASE_MODE}" == "${RELEASE_MODE_ACCEPTANCE}" ]]; then

    # Record acceptance of the config
    save_product_config "${DETAIL_MESSAGE}" "${PRODUCT_CONFIG_REFERENCE}" "${RELEASE_MODE_TAG}"
    RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

    # Record acceptance of the infrastructure
    save_product_infrastructure "${DETAIL_MESSAGE}" "${PRODUCT_INFRASTRUCTURE_REFERENCE}" "${RELEASE_MODE_TAG}"
    RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit
fi

# All good
RESULT=0
