#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Get all the slice commit information
${AUTOMATION_DIR}/manageBuildReferences.sh -f \
    -g ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT}/appsettings/${FROM_SEGMENT}
RESULT=$?


