#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Add release number to details
DETAIL_MESSAGE="release=${RELEASE_TAG}, ${DETAIL_MESSAGE}"
save_context_property DETAIL_MESSAGE

# All good
RESULT=0