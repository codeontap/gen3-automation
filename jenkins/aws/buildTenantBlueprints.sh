#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Usage - This script should be called from the directory where a generated blueprint is stored.
# This would ideally be tirggered using a git hook from an automation server

function main() {
    if [[ -z "${AUTOMATION_REGISTRY_REPO}" ]]; then
        fatal "No automation registry available"
        return 255
    fi

    # Make sure we are in the build source directory
    cd ${AUTOMATION_BUILD_SRC_DIR}

    local BLUEPRINT_CONSOLIDATION_DIR="${AUTOMATION_BUILD_SRC_DIR}/registry"

    ${AUTOMATION_DIR}/manageRepo.sh -c -l "blueprint consolidation" \
        -n "${AUTOMATION_REGISTRY_REPO}" -v "${ACCOUNT_GIT_PROVIDER}" \
        -d "${BLUEPRINT_CONSOLIDATION_DIR}" 

    if [[ -n "${INFRADOCS_PREFIX}" ]]; then
        local BLUEPRINT_CONSOLIDATION_DIR="${AUTOMATION_BUILD_SRC_DIR}/registry/"
    fi 

    local BLUEPRINT_DESTINATION_DIR="${BLUEPRINT_CONSOLIDATION_DIR}/blueprints/content"
    local BLUEPRINT_DESTINATION_FILE="${BLUEPRINT_DESTINATION_DIR}/${TENANT}-${PRODUCT}-${ENVIRONMENT}-${SEGMENT}-blueprint.json"

    info "blueprint repo ${BLUEPRINT_DESTINATION_DIR}"

    if [[ -f "${AUTOMATION_BUILD_SRC_DIR}/blueprint.json" ]]; then 

        if [[ ! -d "${BLUEPRINT_DESTINATION_DIR}" ]]; then 
            mkdir -p "${BLUEPRINT_DESTINATION_DIR}"
        fi 

        echo "Adding Blueprint to Tenant Infrastructure..."
        cp "${AUTOMATION_BUILD_SRC_DIR}/blueprint.json" "${BLUEPRINT_DESTINATION_FILE}"
    
    else

        if [[ -f "${BLUEPRINT_DESTINATION_FILE}" ]]; then 
            echo "Removing Blueprint from Tenant Infrastructure..."
            rm "${BLUEPRINT_DESTINATION_FILE}"
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

