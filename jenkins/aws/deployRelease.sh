#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Update the stacks
${AUTOMATION_DIR}/manageStacks.sh
RESULT=$?
[[ ${RESULT} -ne 0 ]] && exit

# Add release and deployment tags to details
DETAIL_MESSAGE="deployment=${RELEASE_TAG}, release=${RELEASE_TAG}, ${DETAIL_MESSAGE}"
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${AUTOMATION_DATA_DIR}/context.properties

# All good
RESULT=0

