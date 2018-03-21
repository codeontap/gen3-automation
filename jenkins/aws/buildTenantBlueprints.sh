#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Usage - This script should be called from the directory where a generated blueprint is stored.
# This would ideally be tirggered using a git hook from an automation server

function main() {
    # Make sure we are in the build source directory
    cd ${AUTOMATION_BUILD_SRC_DIR}

    # If an Infradocs repo has been setup then clone it, otherwise use the Tenant Infrastructure directory
    if [[ -n "${INFRADOCS_REPO}" ]]; then

        local BLUEPRINT_CONSOLIDATION_DIR="${AUTOMATION_BUILD_SRC_DIR}/repo"

        ${AUTOMATION_DIR}/manageRepo.sh -c -l "blueprint consolidation" \
            -n "${BLUEPRINT_CONSOLIDATION_REPO}" -v "${ACCOUNT_GIT_PROVIDER}" \
            -d "${BLUEPRINT_CONSOLIDATION_DIR}" 
    
        if [[ -n "${INFRADOCS_PREFIX}" ]]; then
            local BLUEPRINT_CONSOLIDATION_DIR="${AUTOMATION_BUILD_SRC_DIR}/repo/${INFRADOCS_PREFIX}"
        fi 

    else 
    
        local BLUEPRINT_CONSOLIDATION_DIR="${TENANT_INFRASTRUCTURE_DIR}/cot"
    
    fi

    local BLUEPRINT_DESTINATION_DIR="${BLUEPRINT_CONSOLIDATION_DIR}/blueprints/${TENANT}/${PRODUCT}/${ENVIRONMENT}/${SEGMENT}/"

    info "blueprint repo ${BLUEPRINT_CONSOLIDATION_REPO}"

    info "tenant infrastructure ${TENANT_INFRASTRUCTURE_DIR}"
    info "blueprint destination ${BLUEPRINT_DESTINATION_DIR}"
    info "blueprint repo ${BLUEPRINT_CONSOLIDATION_REPO}"

    info "blueprint destination ${BLUEPRINT_DESTINATION_DIR}"
    info "blueprint repo ${BLUEPRINT_CONSOLIDATION_REPO}"

    if [[ -f "${AUTOMATION_BUILD_SRC_DIR}/blueprint.json" ]]; then 

        if [[ ! -d "${BLUEPRINT_DESTINATION_DIR}" ]]; then 
            mkdir -p "${BLUEPRINT_DESTINATION_DIR}"
        fi 

        echo "Adding Blueprint to Tenant Infrastructure..."
        cp "${AUTOMATION_BUILD_SRC_DIR}/blueprint.json" "${BLUEPRINT_DESTINATION_DIR}/blueprint.json"
    
    else

        if [[ -f "${BLUEPRINT_DESTINATION_DIR}/blueprint.json" ]]; then 
            echo "Removing Blueprint from Tenant Infrastructure..."
            rm "${BLUEPRINT_DESTINATION_DIR}/blueprint.json"
        fi 
    fi

    DETAIL_MESSAGE="${DETAIL_MESSAGE}, blueprint consolidation"
    ${AUTOMATION_DIR}/manageRepo.sh -p \
        -d "${BLUEPRINT_CONSOLIDATION_DIR}" \
        -l "blueprint consolidation" \
        -m "${DETAIL_MESSAGE}" 

  # All good
  return 0
}

main "$@"

