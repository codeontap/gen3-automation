#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Get all the deployment unit commit information
${AUTOMATION_DIR}/manageBuildReferences.sh -f
RESULT=$?


