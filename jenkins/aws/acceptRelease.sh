#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Tag the builds
${AUTOMATION_DIR}/manageBuildReferences.sh -a "${RELEASE_TAG}"
RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then exit; fi

# Include the build information in the detail message
${AUTOMATION_DIR}/manageBuildReferences.sh -l
RESULT=$?

