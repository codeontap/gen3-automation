#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
    if [[ "${SEGMENT}" == "default" ]]; then
        TAG="deploy${AUTOMATION_JOB_IDENTIFIER}-${PRODUCT}-${ENVIRONMENT}"
    else
        TAG="deploy${AUTOMATION_JOB_IDENTIFIER}-${PRODUCT}-${ENVIRONMENT}-${SEGMENT}"
    fi
    # Create the templates
    ${AUTOMATION_DIR}/manageUnits.sh -l "application" -a "${DEPLOYMENT_UNIT_LIST}" -r "${PRODUCT_CONFIG_COMMIT}" || return $?

    # All ok so tag the config repo
    save_product_config "${DETAIL_MESSAGE}" "${PRODUCT_CONFIG_REFERENCE}" "${TAG}" || return $?

    # Commit the generated application templates
    save_product_infrastructure "${DETAIL_MESSAGE}" "${PRODUCT_INFRASTRUCTURE_REFERENCE}" "${TAG}" || return $?
}

main "$@"
