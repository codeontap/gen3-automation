#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Note that filename can still overridden via provided parameters
${AUTOMATION_DIR}/manageS3Registry.sh -x -y "swagger" -f "swagger.zip" "$@"

if [[ -f "apidoc.zip" ]]; then 
    ${AUTOMATION_DIR}/manageS3Registry.sh -x -y "swagger" -f "apidoc.zip" "$@"
fi

RESULT=$?

