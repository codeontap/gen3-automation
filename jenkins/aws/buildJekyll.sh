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

  # Default Timezone 
  if [[ -z "${JEKYLL_TIMEZONE}" ]]; then
    JEKYLL_TIMEZONE="Australia/Sydney"
  fi

  # Default build Env 
  if [[ -z "${JEKYLL_ENV}" ]]; then
    JEKYLL_ENV="production"
  fi

  # Create Build folders for Jenkins Permissions
  touch ${AUTOMATION_BUILD_SRC_DIR}/Gemfile.lock
  chmod a+w ${AUTOMATION_BUILD_SRC_DIR}/Gemfile.lock

  mkdir -p ${AUTOMATION_BUILD_SRC_DIR}/_site
  chmod a+rwx ${AUTOMATION_BUILD_SRC_DIR}/_site

  # run Jekyll build using Docker Build image 
  info "Running Jeykyll build"
  docker run --rm \
    --env JEKYLL_ENV="${JEKYLL_ENV}" \
    --env TZ="${JEKYLL_TIMEZONE}" \
    --volume="${AUTOMATION_BUILD_SRC_DIR}:/srv/jekyll" \
    jekyll/builder:"${JEKYLL_VERSION}" \
    jekyll build --verbose 
    
  # Package for spa if required
  if [[ -f "${AUTOMATION_BUILD_SRC_DIR}/_site/${JEKYLL_DEFAULT_PAGE}" ]]; then

    # Allow access to all files that have been generated so they can be cleaned up. 
    chmod a+rwx  "${AUTOMATION_BUILD_SRC_DIR}/_site"
    chmod -R a+rwx  "${AUTOMATION_BUILD_SRC_DIR}/_site/"

    mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/dist"
    
    cd "${AUTOMATION_BUILD_SRC_DIR}/_site"
    zip -r "${AUTOMATION_BUILD_SRC_DIR}/dist/spa.zip" * 
  fi

  # All good
  return 0
}

main "$@"

