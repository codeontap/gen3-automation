#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${GENERATION_DIR}/common.sh"

cd ${AUTOMATION_DATA_DIR}/${INTEGRATOR}

# Add the tenant
${GENERATION_DIR}/integrator/addTenant.sh
RESULT=$?
[[ ${RESULT} -ne 0 ]] && fatal "Can't add tenant"

# Save the additions to the repo
${AUTOMATION_DIR}/manageRepo.sh -n ${INTEGRATOR_REPO} -m "Added tenant ${TENANT}"
RESULT=$?
