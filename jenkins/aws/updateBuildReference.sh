#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Update build references
${AUTOMATION_DIR}/manageBuildReferences.sh -u
RESULT=$?
[[ ${RESULT} -ne 0 ]] && exit

TAG_SWITCH=()
if [[ -n "${RELEASE_MODE_TAG}" ]]; then
    TAG_SWITCH=("-t" "${RELEASE_MODE_TAG}")
fi

${AUTOMATION_DIR}/manageRepo.sh -p \
    -d ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT} \
    -l "config" \
    -m "${DETAIL_MESSAGE}" \
    "${TAG_SWITCH[@]}" \
    -b ${PRODUCT_CONFIG_REFERENCE}
RESULT=$?
[[ ${RESULT} -ne 0 ]] && exit

if [[ (-n "${AUTODEPLOY+x}") &&
        ("$AUTODEPLOY" != "true") ]]; then
    RESULT=2
    fatal "AUTODEPLOY is not true, triggering exit"
fi

# Record key parameters for downstream jobs
echo "DEPLOYMENT_UNITS=${DEPLOYMENT_UNIT_LIST}" >> ${AUTOMATION_DATA_DIR}/chain.properties

# All good
RESULT=0


