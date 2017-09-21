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
RESULT=$?
[[ ${RESULT} -ne 0 ]] && exit

# All ok so tag the config repo
${AUTOMATION_DIR}/manageRepo.sh -p \
    -d ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT} \
    -l "config" \
    -t ${RELEASE_TAG} \
    -m "${DETAIL_MESSAGE}" \
    -b ${PRODUCT_CONFIG_REFERENCE}
RESULT=$?
[[ ${RESULT} -ne 0 ]] && exit

# Commit the generated application templates
${AUTOMATION_DIR}/manageRepo.sh -p \
    -d ${AUTOMATION_DATA_DIR}/${ACCOUNT}/infrastructure/${PRODUCT} \
    -l "infrastructure" \
    -t ${RELEASE_TAG} \
    -m "${DETAIL_MESSAGE}" \
    -b ${PRODUCT_INFRASTRUCTURE_REFERENCE}
RESULT=$?
[[ ${RESULT} -ne 0 ]] && exit

# Record key parameters for downstream jobs
echo "RELEASE_IDENTIFIER=${AUTOMATION_RELEASE_IDENTIFIER}" >> $AUTOMATION_DATA_DIR/chain.properties

# All good
RESULT=0
