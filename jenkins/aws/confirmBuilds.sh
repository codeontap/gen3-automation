#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Ensure mandatory arguments have been provided
[[ (-z "${RELEASE_MODE}") ||
    (-z "${ACCEPTANCE_TAG}") ]] && fatalMandatory

# Verify the reference updates
${AUTOMATION_DIR}/manageBuildReferences.sh -v ${ACCEPTANCE_TAG}
RESULT=$?
[[ "${RESULT}" -ne 0 ]] && exit

# Include the build information in the detail message
${AUTOMATION_DIR}/manageBuildReferences.sh -l
RESULT=$?
