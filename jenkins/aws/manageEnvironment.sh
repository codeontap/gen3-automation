#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
  if [[ "${SEGMENT}" == "default" ]]; then
    TAG="env${AUTOMATION_JOB_IDENTIFIER}-${PRODUCT}-${ENVIRONMENT}"
  else
    TAG="env${AUTOMATION_JOB_IDENTIFIER}-${PRODUCT}-${ENVIRONMENT}-${SEGMENT}"
  fi

  ${AUTOMATION_DIR}/manageUnits.sh -r "${TAG}" || return $?

  # All ok so tag the config repo
  save_product_config "${DETAIL_MESSAGE}" "${PRODUCT_CONFIG_REFERENCE}" "${TAG}" || return $?
  
  # Commit the generated application templates
  save_product_infrastructure "${DETAIL_MESSAGE}" "${PRODUCT_INFRASTRUCTURE_REFERENCE}" "${TAG}" || return $?
}

main "$@"

