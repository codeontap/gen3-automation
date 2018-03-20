#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
  # Make sure we are in the build source directory
  cd ${AUTOMATION_BUILD_SRC_DIR}
  
  # Create Build folders for Jenkins Permissions
  mkdir -p ${AUTOMATION_BUILD_SRC_DIR}/dist
  chmod a+rwx ${AUTOMATION_BUILD_SRC_DIR}/dist

  # run Model Bender build using Docker Build image 
  info "Running ModelBender build"
  docker run --rm \
    --volume="${AUTOMATION_BUILD_SRC_DIR}/outdir:/_tmp" \
    --volume="${AUTOMATION_BUILD_SRC_DIR}:/work/indir" \
    codeontap/modelbender:latest \
    enterprise --indir=indir

  # package for content node
  if [[ -d "${AUTOMATION_BUILD_SRC_DIR}" ]]; then
    mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/dist"
    
    cd "${AUTOMATION_BUILD_SRC_DIR}/outdir"
    zip -r "${AUTOMATION_BUILD_SRC_DIR}/dist/contentnode.zip" * 

  fi

  # All good
  return 0
}

main "$@"

