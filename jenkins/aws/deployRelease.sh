#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
  # Update the stacks
  ${AUTOMATION_DIR}/manageUnits.sh -l "application" -a "${DEPLOYMENT_UNIT_LIST}" || return $?

  # Add release and deployment tags to details
  DETAIL_MESSAGE="deployment=${DEPLOYMENT_TAG}, release=${RELEASE_TAG}, ${DETAIL_MESSAGE}"
  save_context_property DETAIL_MESSAGE

  # All ok so tag the config repo
  save_product_config "${DETAIL_MESSAGE}" "${PRODUCT_CONFIG_REFERENCE}" "${DEPLOYMENT_TAG}" || return $?

  # Commit the generated application templates
  save_product_infrastructure "${DETAIL_MESSAGE}" "${PRODUCT_INFRASTRUCTURE_REFERENCE}" "${DEPLOYMENT_TAG}" || return $?
}

main "$@"
