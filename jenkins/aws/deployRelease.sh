#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Update the stacks
${AUTOMATION_DIR}/manageStacks.sh
RESULT=$?
[[ ${RESULT} -ne 0 ]] && exit

# Add release and deployment tags to details
DETAIL_MESSAGE="deployment=${DEPLOYMENT_TAG}, release=${RELEASE_TAG}, ${DETAIL_MESSAGE}"
save_context_property DETAIL_MESSAGE

# All good
RESULT=0

