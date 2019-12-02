#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Note that registry and filename can still overridden via parameters
# provided to this script. The defaults below will be processed but immediately
# replaced with any switches provided to this script.
${AUTOMATION_DIR}/manageS3Registry.sh -x -y "openapi" -f "openapi.zip" "$@"

RESULT=$?

