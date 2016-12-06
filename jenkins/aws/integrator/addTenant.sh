#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

cd ${AUTOMATION_DATA_DIR}/${INTEGRATOR}

# Add the tenant
${GENERATION_DIR}/integrator/addTenant.sh
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
	echo "Can't add tenant, exiting..."
	exit
fi

# Save the additions to the repo
${AUTOMATION_DIR}/manageRepo.sh -n ${INTEGRATOR_REPO} -m "Added tenant ${TENANT}"
RESULT=$?
