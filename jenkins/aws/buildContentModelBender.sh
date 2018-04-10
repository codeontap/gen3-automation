#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
  # Make sure we are in the build source directory
  cd ${AUTOMATION_BUILD_SRC_DIR}
  
  # Create Build folders for Jenkins Permissions
  mkdir -p ${AUTOMATION_BUILD_SRC_DIR}/stage
  chmod a+rwx ${AUTOMATION_BUILD_SRC_DIR}/stage

  # run Model Bender build using Docker Build image 
  info "Running ModelBender enterprise tasks..."
  docker run --rm \
    --volume="${AUTOMATION_BUILD_SRC_DIR}:/work/indir" \
    --volume="${AUTOMATION_BUILD_SRC_DIR}/stage:/work/outdir" \
    codeontap/modelbender:latest \
    enterprise --indir=indir --outdir=outdir

  info "Rendering ModelBender content..."
  docker run --rm \
    --volume="${AUTOMATION_BUILD_SRC_DIR}/stage:/work/indir" \
    codeontap/modelbender:latest \
    render --indir=indir

  mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/dist"
  
  cd "${AUTOMATION_BUILD_SRC_DIR}/stage"
  zip -r "${AUTOMATION_BUILD_SRC_DIR}/dist/contentnode.zip" * 

  # All good
  return 0
}

main "$@"

