#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

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

  # run Jekyll build using Docker Build image 
  info "Running Jeykyll build"
  docker run --rm \
    --volume="${AUTOMATION_BUILD_SRC_DIR}:/srv/jekyll" \
    -it jekyll/builder:$JEKYLL_VERSION \
    jekyll build
    
  # Package for spa if required
  if [[ -f "${AUTOMATION_BUILD_SRC_DIR}/_site/${JEKYLL_DEFAULT_PAGE}" ]]; then
    mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/dist"
    zip -rj "${AUTOMATION_BUILD_SRC_DIR}/dist/spa.zip" "${AUTOMATION_BUILD_SRC_DIR}/_site" 
  fi

  # All good
  return 0
}

main "$@"

