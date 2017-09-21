#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Create the templates
${AUTOMATION_DIR}/createTemplates.sh -t application -c "${PRODUCT_CONFIG_COMMIT}"
RESULT=$?
[[ ${RESULT} -ne 0 ]] && exit

# Update the stacks
${AUTOMATION_DIR}/manageStacks.sh
RESULT=$?

