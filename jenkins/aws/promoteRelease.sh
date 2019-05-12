#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

RELEASE_MODE_PROMOTION="promotion"

# Ensure mandatory arguments have been provided
[[ (-z "${RELEASE_MODE}") ||
    (-z "${ACCEPTANCE_TAG}") ]] && fatalMandatory

# Verify the build information
if [[ "${RELEASE_MODE}" == "${RELEASE_MODE_PROMOTION}" ]]; then

    # Get the from settings in a separate dir - name it differently
    # in case both segments in the same repo
    FROM_PRODUCT_BASE_DIR="${AUTOMATION_DATA_DIR}/from_product"
    FROM_PRODUCT_TEMP_DIR="${FROM_PRODUCT_BASE_DIR}/temp"
    mkdir -p "${FROM_PRODUCT_TEMP_DIR}"
    ${AUTOMATION_DIR}/manageRepo.sh -c -l "from product config" \
        -n "${FROM_PRODUCT_CONFIG_REPO}" -v "${FROM_PRODUCT_GIT_PROVIDER}" \
        -d "${FROM_PRODUCT_TEMP_DIR}" -b "${ACCEPTANCE_TAG}"
    RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit

    # Allow for composite repos
    if [[ -n $(findDir "${FROM_PRODUCT_TEMP_DIR}" "${PRODUCT}") ]]; then
        FROM_PRODUCT_ROOT_DIR="${FROM_PRODUCT_BASE_DIR}/config"
    else
        FROM_PRODUCT_ROOT_DIR="${FROM_PRODUCT_BASE_DIR}/${PRODUCT}"
    fi
    mv "${FROM_PRODUCT_TEMP_DIR}" "${FROM_PRODUCT_ROOT_DIR}"

    # Find the product appsettings directory
    FROM_BUILDS_DIR="$(findGen3ProductBuildsDir "${FROM_PRODUCT_BASE_DIR}" "${PRODUCT}")/${FROM_ENVIRONMENT}/${SEGMENT}"

    # Pull in the current build references in lower segment
    ${AUTOMATION_DIR}/manageBuildReferences.sh -f -g ${FROM_BUILDS_DIR}
    RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit
fi

# All good
RESULT=0