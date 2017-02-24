#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Ensure mandatory arguments have been provided
if [[ (-z "${RELEASE_MODE}") ||
        (-z "${ACCEPTANCE_TAG}") ]]; then
    echo -e "\nInsufficient arguments" >&2
    exit
fi

# Verify the reference updates
${AUTOMATION_DIR}/manageBuildReferences.sh -v ${ACCEPTANCE_TAG}
RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then exit; fi

# Include the build information in the detail message
${AUTOMATION_DIR}/manageBuildReferences.sh -l
RESULT=$?
