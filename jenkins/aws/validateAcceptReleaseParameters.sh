#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Ensure RELEASE_IDENTIFIER have been provided
[[ -z "${RELEASE_IDENTIFIER}" ]] &&
    fatal "Job requires the identifier of the release to be accepted" && exit

# Don't forget -c ${RELEASE_TAG} -i ${RELEASE_TAG} on constructTree.sh

# All good
RESULT=0


