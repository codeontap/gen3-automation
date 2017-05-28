#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Note that filename can still overridden via provided parameters
${AUTOMATION_DIR}/manageS3Registry.sh -y "cloudfront" -f "bundle.zip" "$@"
RESULT=$?

