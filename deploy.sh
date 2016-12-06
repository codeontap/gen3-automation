#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Create the templates
${AUTOMATION_DIR}/createTemplates.sh -t application -c "${PRODUCT_CONFIG_COMMIT}"
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then exit; fi

# Update the stacks
${AUTOMATION_DIR}/manageStacks.sh
RESULT=$?

