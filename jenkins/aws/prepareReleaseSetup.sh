#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Add release number to details
DETAIL_MESSAGE="release=${RELEASE_TAG}, ${DETAIL_MESSAGE}"
save_context_property DETAIL_MESSAGE

# All good
RESULT=0