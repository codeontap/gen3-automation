#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
  [[ -n "${ACCOUNTS_LIST}" ]] &&
    TAG="acc${AUTOMATION_JOB_IDENTIFIER}-${ACCOUNTS_LIST}" ||
    TAG="acc${AUTOMATION_JOB_IDENTIFIER}-${ACCOUNT}"

  ${AUTOMATION_DIR}/manageUnits.sh -r "${TAG}" || return $?

  # All ok so tag the config repo
  save_repo "${ACCOUNT_DIR}" "account config" \
    "${DETAIL_MESSAGE}" "${PRODUCT_CONFIG_REFERENCE}" "${TAG}" || return $?
  
  # Commit the generated application templates
  save_repo "${ACCOUNT_INFRASTRUCTURE_DIR}" "account infrastructure" "${DETAIL_MESSAGE}" "${PRODUCT_INFRASTRUCTURE_REFERENCE}" "${TAG}" || return $?
}

main "$@"



