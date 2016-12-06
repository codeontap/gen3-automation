#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Update build references
${AUTOMATION_DIR}/manageBuildReferences.sh -u
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then exit; fi

# Create the templates
${AUTOMATION_DIR}/createTemplates.sh -t application -c "${RELEASE_TAG}"
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then exit; fi

# All ok so tag the config repo
${AUTOMATION_DIR}/manageRepo.sh -p \
    -d ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT} \
    -n config \
    -t ${RELEASE_TAG} \
    -m "${DETAIL_MESSAGE}" \
    -b ${PRODUCT_CONFIG_REFERENCE}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then exit; fi

# Commit the generated application templates
${AUTOMATION_DIR}/manageRepo.sh -p \
    -d ${AUTOMATION_DATA_DIR}/${ACCOUNT}/infrastructure/${PRODUCT} \
    -n infrastructure \
    -t ${RELEASE_TAG} \
    -m "${DETAIL_MESSAGE}" \
    -b ${PRODUCT_INFRASTRUCTURE_REFERENCE}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then exit; fi

# All good
RESULT=0