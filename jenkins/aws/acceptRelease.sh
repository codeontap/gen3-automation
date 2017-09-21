#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Include the build information in the detail message
${AUTOMATION_DIR}/manageBuildReferences.sh -l
RESULT=$?
[[ "${RESULT}" -ne 0 ]] && exit

# Tag the builds
${AUTOMATION_DIR}/manageBuildReferences.sh -a "${RELEASE_TAG}"
RESULT=$?


