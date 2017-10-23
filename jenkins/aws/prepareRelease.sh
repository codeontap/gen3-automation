#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Update build references
${AUTOMATION_DIR}/manageBuildReferences.sh -u
RESULT=$?
[[ ${RESULT} -ne 0 ]] && exit

# Create the templates
${AUTOMATION_DIR}/createTemplates.sh -t application -c "${RELEASE_TAG}"
RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

# All ok so tag the config repo
save_product_config "${DETAIL_MESSAGE}" "${PRODUCT_CONFIG_REFERENCE}" "${RELEASE_TAG}"
RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

# Commit the generated application templates
save_product_infrastructure "${DETAIL_MESSAGE}" "${PRODUCT_INFRASTRUCTURE_REFERENCE}" "${RELEASE_TAG}"
RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

# Record key parameters for downstream jobs
save_context_property RELEASE_IDENTIFIER "${AUTOMATION_RELEASE_IDENTIFIER}"

# All good
RESULT=0
