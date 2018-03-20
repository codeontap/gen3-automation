#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
    # Make sure we are in the build source directory
    cd ${AUTOMATION_BUILD_SRC_DIR}
  
    if [[ -f "${AUTOMATION_BUILD_SRC_DIR}/blueprint.json"]]; then 

        echo "Adding Blueprint to Tenant Infrastructure..."
        cp "${AUTOMATION_BUILD_SRC_DIR}/blueprint.json" "${TENANT_INFRASTRUCTURE_DIR}/cot/blueprints/${TENANT}/${PRODUCT}/${ENVIRONMENT}/${SOLUTION}/${SEGMENT}/blueprint.json"
    
    else

        if [[ -f "${TENANT_INFRASTRUCTURE_DIR}/cot/blueprints/${TENANT}/${PRODUCT}/${ENVIRONMENT}/${SOLUTION}/${SEGMENT}/blueprint.json" ]]; then 
            echo "Removing Blueprint from Tenant Infrastructure..."
            rm "${TENANT_INFRASTRUCTURE_DIR}/cot/blueprints/${TENANT}/${PRODUCT}/${ENVIRONMENT}/${SOLUTION}/${SEGMENT}/blueprint.json"
        fi 
  fi
  
  # All good
  return 0
}

main "$@"

