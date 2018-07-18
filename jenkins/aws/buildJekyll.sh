#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

dockerstagedir="$(getTempDir "cota_docker_XXXX" "${DOCKER_STAGE_DIR}")"
chmod a+rwx "${dockerstagedir}"

function main() {
  # Make sure we are in the build source directory
  cd ${AUTOMATION_BUILD_SRC_DIR}
  
  # Is this really a jekyll based project
  [[ ! -f _config.yml ]] &&
    { fatal "No _config.yml - is this really a jekyll based repo?"; return 1; }

  # Unless specified use the latest Jekyll version 
  if [[ -z "${JEKYLL_VERSION}" ]]; then
    JEKYLL_VERSION=latest
  fi

  # Default Document for generation testing
  if [[ -z "${JEKYLL_DEFAULT_PAGE}" ]]; then
    JEKYLL_DEFAULT_PAGE=index.html
  fi 

  # Default Timezone 
  if [[ -z "${JEKYLL_TIMEZONE}" ]]; then
    JEKYLL_TIMEZONE="Australia/Sydney"
  fi

  # Default build Env 
  if [[ -z "${JEKYLL_ENV}" ]]; then
    JEKYLL_ENV="production"
  fi

  mkdir "${dockerstagedir}/indir"
  cp -R "${AUTOMATION_BUILD_SRC_DIR}/"  "${dockerstagedir}/indir"

  # run Jekyll build using Docker Build image 
  info "Running Jeykyll build"
  docker run --rm \
    --env JEKYLL_ENV="${JEKYLL_ENV}" \
    --env TZ="${JEKYLL_TIMEZONE}" \
    --volume="${dockerstagedir}/indir:/srv/jekyll" \
    jekyll/builder:"${JEKYLL_VERSION}" \
    jekyll build --verbose 
    
  # Package for spa if required
  if [[ -f "${dockerstagedir}/indir/_site/${JEKYLL_DEFAULT_PAGE}" ]]; then

    # Allow access to all files that have been generated so they can be cleaned up. 
    cd "${dockerstagedir}/indir/_site"
    
    mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/dist"
    zip -r "${AUTOMATION_BUILD_SRC_DIR}/dist/spa.zip" * 
  fi

  # All good
  return 0
}

main "$@"

