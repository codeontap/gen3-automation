#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

dockerstagedir="$(getTempDir "cota_docker_XXXXXX" "${DOCKER_STAGE_DIR}")"
chmod a+rwx "${dockerstagedir}"

function main() {
  # Make sure we are in the build source directory
  cd ${AUTOMATION_BUILD_SRC_DIR}
  
  # Create Build folders for Jenkins Permissions
  mkdir -p ${AUTOMATION_BUILD_SRC_DIR}/stage
  mkdir -p "${dockerstagedir}/indir"
  mkdir -p "${dockerstagedir}/stage"

  cp -r "${AUTOMATION_BUILD_SRC_DIR}"/* "${dockerstagedir}/indir/"

  # run Model Bender build using Docker Build image 
  info "Running ModelBender enterprise tasks..."
  docker run --rm \
    --volume="${dockerstagedir}/indir:/work/indir" \
    --volume="${dockerstagedir}/stage:/work/outdir" \
    codeontap/modelbender:latest \
    enterprise --indir=indir --outdir=outdir

  info "Rendering ModelBender content..."
  docker run --rm \
    --volume="${dockerstagedir}/stage:/work/indir" \
    codeontap/modelbender:latest \
    render --indir=indir

  cd "${dockerstagedir}/stage"

  mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/dist"
  zip -r "${AUTOMATION_BUILD_SRC_DIR}/dist/contentnode.zip" * 

  # All good
  return 0
}

main "$@"

