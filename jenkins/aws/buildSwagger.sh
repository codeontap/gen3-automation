#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# All the logic is in the openapi build
${AUTOMATION_DIR}/buildOpenapi.sh "$@"
RESULT=$?