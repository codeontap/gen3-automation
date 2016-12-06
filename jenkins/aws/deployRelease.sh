#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Update the stacks
${AUTOMATION_DIR}/manageStacks.sh
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then exit; fi

# Add release and deployment tags to details
DETAIL_MESSAGE="deployment=d${BUILD_NUMBER}-${SEGMENT}, release=${RELEASE_TAG}, ${DETAIL_MESSAGE}"
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${AUTOMATION_DATA_DIR}/context.properties

# All good
RESULT=0

