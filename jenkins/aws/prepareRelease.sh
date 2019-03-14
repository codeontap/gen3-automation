#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
  # Update build references
  ${AUTOMATION_DIR}/manageBuildReferences.sh -u || return $?
  
  # Create the templates
  ${AUTOMATION_DIR}/manageUnits.sh -l "application" -a "${DEPLOYMENT_UNIT_LIST}" -r "${RELEASE_TAG}" || return $?
  
  # All ok so tag the config repo
  save_product_config "${DETAIL_MESSAGE}" "${PRODUCT_CONFIG_REFERENCE}" "${RELEASE_TAG}" || return $?
  
  # Commit the generated application templates
  save_product_infrastructure "${DETAIL_MESSAGE}" "${PRODUCT_INFRASTRUCTURE_REFERENCE}" "${RELEASE_TAG}" || return $?

  # Record key parameters for downstream jobs
  save_context_property RELEASE_IDENTIFIER "${AUTOMATION_RELEASE_IDENTIFIER}"

  return 0
}

main "$@"
