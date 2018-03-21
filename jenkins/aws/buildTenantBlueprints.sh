#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
    # Make sure we are in the build source directory
    cd ${AUTOMATION_BUILD_SRC_DIR}

    BLUEPRINT_CONSOLIDATION_PREFIX="${INFRADOCS_DIR:-${TENANT_INFRASTRUCTURE_DIR}}"
    BLUEPRINT_CONSOLIDATION_REPO="${INFRADOCS_REPO:-${ACCOUNT_INFRASTRUCTURE_REPO}}"

    BLUEPRINT_CONSOLIDATION_TEMP="${AUTOMATION_BUILD_SRC_DIR}/blueprints"
    BLUEPRINT_CONSOLIDATION_DIR="${BLUEPRINT_CONSOLIDATION_TEMP}/${BLUEPRINT_CONSOLIDATION_PREFIX}"

    ${AUTOMATION_DIR}/manageRepo.sh -c -l "blueprint consolidation" \
    -n "${BLUEPRINT_CONSOLIDATION_REPO}" -v "${ACCOUNT_GIT_PROVIDER}" \
    -d "${BLUEPRINT_CONSOLIDATION_TEMP}"

    if [[ -f "${AUTOMATION_BUILD_SRC_DIR}/blueprint.json"]]; then 

        echo "Adding Blueprint to Tenant Infrastructure..."
        cp "${AUTOMATION_BUILD_SRC_DIR}/blueprint.json" "${BLUEPRINT_CONSOLIDATION_DIR}/cot/blueprints/${TENANT}/${PRODUCT}/${ENVIRONMENT}/${SOLUTION}/${SEGMENT}/blueprint.json"
    
    else

        if [[ -f "${BLUEPRINT_CONSOLIDATION_DIR}/cot/blueprints/${TENANT}/${PRODUCT}/${ENVIRONMENT}/${SOLUTION}/${SEGMENT}/blueprint.json" ]]; then 
            echo "Removing Blueprint from Tenant Infrastructure..."
            rm "${BLUEPRINT_CONSOLIDATION_DIR}/cot/blueprints/${TENANT}/${PRODUCT}/${ENVIRONMENT}/${SOLUTION}/${SEGMENT}/blueprint.json"
        fi 
    fi

    DETAIL_MESSAGE="${DETAIL_MESSAGE}, blueprint consolidation"
    save_repo "${BLUEPRINT_CONSOLIDATION_DIR}" "blueprint consolidation" "${DETAIL_MESSAGE}"  || return $?

  # All good
  return 0
}

main "$@"

