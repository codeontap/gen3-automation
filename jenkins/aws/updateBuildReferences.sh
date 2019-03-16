#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Update build references
${AUTOMATION_DIR}/manageBuildReferences.sh -u
RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

# Save the results
save_product_config "${DETAIL_MESSAGE}" "${PRODUCT_CONFIG_REFERENCE}" "${RELEASE_MODE_TAG}"
RESULT=$? && [[ ${RESULT} -ne 0 ]] && exit

if [[ (-n "${AUTODEPLOY+x}") &&
        ("$AUTODEPLOY" != "true") ]]; then
    RESULT=2
    fatal "AUTODEPLOY is not true, triggering exit" && exit
fi

# Record key parameters for downstream jobs
save_chain_property DEPLOYMENT_UNITS "${DEPLOYMENT_UNIT_LIST}"

# All good
RESULT=0


