#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Get all the deployment unit commit information
${AUTOMATION_DIR}/manageBuildReferences.sh -f
RESULT=$?


