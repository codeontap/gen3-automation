#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

dockertmpdir="$(getTempDir "cota_docker_XXXX" "${DOCKER_STAGE_DIR}")"
chmod a+rwx "${dockertmpdir}"

function main() {
  # Make sure we are in the build source directory
  cd ${AUTOMATION_BUILD_SRC_DIR}
  
  # Create Build folders for Jenkins Permissions
  mkdir -p ${AUTOMATION_BUILD_SRC_DIR}/stage
  mkdir -p "${dockertmpdir}/indir"
  mkdir -p "${dockertmpdir}/stage"

  cp "${AUTOMATION_BUILD_SRC_DIR}" "${dockertmpdir}/indir"

  # run Model Bender build using Docker Build image 
  info "Running ModelBender enterprise tasks..."
  docker run --rm \
    --volume="${dockertmpdir}/indir:/work/indir" \
    --volume="${dockertmpdir}/stage:/work/outdir" \
    codeontap/modelbender:latest \
    enterprise --indir=indir --outdir=outdir

  info "Rendering ModelBender content..."
  docker run --rm \
    --volume="${dockertmpdir}/stage:/work/indir" \
    codeontap/modelbender:latest \
    render --indir=indir

  cd "${dockertmpdir}/stage"

  mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/dist"
  zip -r "${AUTOMATION_BUILD_SRC_DIR}/dist/contentnode.zip" * 

  # All good
  return 0
}

main "$@"

