#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
  # Make sure we are in the build source directory
  cd ${AUTOMATION_BUILD_SRC_DIR}
  
  # Unless specified use the latest InfraDocs version 
  if [[ -z "${INFRADOCS_VERSION}" ]]; then
    INFRADOCS_VERSION=latest
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
    --volume="${AUTOMATION_BUILD_SRC_DIR}:/indir"
    --volume="${AUTOMATION_BUILD_SRC_DIR}/_site:/outdir"
    codeontap/infradocs:"${INFRADOCS_VERSION}" \
    jekyll build --verbose 
    
  # Package for spa if required
  if [[ -f "${AUTOMATION_BUILD_SRC_DIR}/_site/${JEKYLL_DEFAULT_PAGE}" ]]; then
    mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/dist"
    
    cd "${AUTOMATION_BUILD_SRC_DIR}/_site"
    zip -r "${AUTOMATION_BUILD_SRC_DIR}/dist/spa.zip" * 
  else 

    fatal "No default page avaialable"
    return 1
  
  fi

  # All good
  return 0
}

main "$@"

