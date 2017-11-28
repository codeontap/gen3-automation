#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
  # Make sure we are in the build source directory
  cd ${AUTOMATION_BUILD_SRC_DIR}
  
  # Is this really a python based project
  [[ ! -f requirements.txt ]] &&
    { fatal "No requirements.txt - is this really a python base repo?"; return 1; }
  
  # Set up the virtual build environment
  local venv_dir="$(getTempDir "venv_XXX")"
  PYTHON_VERSION="${AUTOMATION_PYTHON_VERSION:+ -p } ${AUTOMATION_PYTHON_VERSION}"

  # Note that python version below should NOT be in quotes to ensure arguments parsed correctly
  virtualenv ${PYTHON_VERSION} "${venv_dir}" ||
    { exit_status=$?; fatal "Creation of virtual build environment failed"; return ${exit_status}; }
  
  . ${venv_dir}/bin/activate
  
  # Process requirements files
  shopt -s nullglob
  REQUIREMENTS_FILES=( requirements*.txt )
  for REQUIREMENTS_FILE in "${REQUIREMENTS_FILES[@]}"; do
    pip install -r ${REQUIREMENTS_FILE} --upgrade ||
    { exit_status=$?; fatal "Installation of requirements failed"; return ${exit_status}; }
  done
  
  if [[ -f package.json ]]; then
    npm install --unsafe-perm ||
      { exit_status=$?; fatal "npm install failed"; return ${exit_status}; }
  fi
  
  # Run bower as part of the build if required
  if [[ -f bower.json ]]; then
    bower install --allow-root ||
      { exit_status=$?; fatal "Bower install failed"; return ${exit_status}; }
  fi
  
  # Run unit tests - there should always be a task even if it does nothing
  if [[ -f manage.py ]]; then
    python manage.py test || return 1
  fi
  
  # Patch the virtual env if packages have not been installed into site-packages dir
  # This is a defect in zappa 0.42, in that it doesn't allow for platforms that install
  # packages into dist-packages. Remove this patch once zappa is fixed
  if [[ -n ${VIRTUAL_ENV} ]]; then
    for lib in "lib" "lib64"; do
      SITE_PACKAGES_DIR=$(find ${VIRTUAL_ENV}/${lib} -name site-packages)
      if [[ -n ${SITE_PACKAGES_DIR} ]]; then
        if [[ $(find ${SITE_PACKAGES_DIR} -type d | wc -l) < 2 ]]; then
          cp -rp ${SITE_PACKAGES_DIR}/../dist-packages/*  ${SITE_PACKAGES_DIR}
        fi
      fi
    done
  fi
  
  # Package for lambda if required
  for ZAPPA_DIR in "${AUTOMATION_BUILD_DEVOPS_DIR}/lambda" "./"; do
    if [[ -f "${ZAPPA_DIR}/zappa_settings.json" ]]; then
      BUILD=$(zappa package default -s ${ZAPPA_DIR}/zappa_settings.json | tail -1 | cut -d' ' -f3)
      if [[ -f ${BUILD} ]]; then
        mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/dist"
        mv ${BUILD} "${AUTOMATION_BUILD_SRC_DIR}/dist/lambda.zip"
      fi
    fi
  done
  
  # Clean up
  if [[ -f package.json ]]; then
    npm prune --production ||
      { exit_status=$?; fatal "npm prune failed"; return ${exit_status}; }
  fi

  [[ -d "${venv_dir}" ]] && rm -rf "${venv_dir}"

  # All good
  return 0
}

main "$@"

