#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Note that filename can still overridden via provided parameters
${AUTOMATION_DIR}/manageRDSRegistry.sh -y "dataset" "$@"
RESULT=$?

