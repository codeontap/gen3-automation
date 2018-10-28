#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Create the templates
${AUTOMATION_DIR}/manageUnits.sh -l "application" -a "${DEPLOYMENT_UNIT_LIST}" -r "${PRODUCT_CONFIG_COMMIT}"


