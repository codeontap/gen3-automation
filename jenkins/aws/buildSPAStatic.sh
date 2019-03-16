#!/usr/bin/env bash
# - Basic build for an SPA that is static content

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
  # Make sure we are in the build source directory
  cd ${AUTOMATION_BUILD_SRC_DIR}
  
  # packge for content node
  mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/dist"
    
  cd "${AUTOMATION_BUILD_SRC_DIR}"
  zip -r "${AUTOMATION_BUILD_SRC_DIR}/dist/spa.zip" * 

  # All good
  return 0
}

main "$@"

