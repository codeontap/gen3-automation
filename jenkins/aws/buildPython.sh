#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") && (-d "${venv_dir}") ]] && rm -rf "${venv_dir}"; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function main() {
  # Make sure we are in the build source directory
  cd ${AUTOMATION_BUILD_SRC_DIR}
  
  # Update git origin url for product code repo to specify automation user credentials for successful push
  [[ -n "${PRODUCT_CODE_REPO}" ]] && git remote set-url origin https://${GITHUB_CREDENTIALS}@${GITHUB_GIT_DNS}/${GITHUB_GIT_ORG}/${PRODUCT_CODE_REPO}.git

  # Determine required tasks
  # test is always required
  [[ -n "${BUILD_TASKS}" ]] && REQUIRED_TASKS=( ${BUILD_TASKS} ) || REQUIRED_TASKS=( "build" "unit" )

  # virtual environment is needed not only for build, but for unit and swagger tasks
  if inArray "REQUIRED_TASKS" "build|unit|swagger"; then
    # Is this really a python based project
    [[ ! -f requirements.txt ]] &&
      { fatal "No requirements.txt - is this really a python base repo?"; return 1; }

    # Set up the virtual build environment
    venv_dir="$(getTempDir "cota_venv_XXX")"
    PYTHON_VERSION="${AUTOMATION_PYTHON_VERSION:+ -p } ${AUTOMATION_PYTHON_VERSION}"

    # Note that python version below should NOT be in quotes to ensure arguments parsed correctly
    virtualenv ${PYTHON_VERSION} "${venv_dir}" ||
      { exit_status=$?; fatal "Creation of virtual build environment failed"; return ${exit_status}; }

    . ${venv_dir}/bin/activate

    # Pin pip if required
    [[ -n "${AUTOMATION_PIP_VERSION}" ]] && pip install "pip==${AUTOMATION_PIP_VERSION}"

    # Process requirements files
    shopt -s nullglob
    REQUIREMENTS_FILES=( requirements*.txt )
    for REQUIREMENTS_FILE in "${REQUIREMENTS_FILES[@]}"; do
      pip install -r ${REQUIREMENTS_FILE} --upgrade ||
      { exit_status=$?; fatal "Installation of requirements failed"; return ${exit_status}; }
    done

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

    if [[ -f package.json ]]; then
      npm install --unsafe-perm ||
        { exit_status=$?; fatal "npm install failed"; return ${exit_status}; }
    fi

    # Run bower as part of the build if required
    if [[ -f bower.json ]]; then
      bower install --allow-root ||
        { exit_status=$?; fatal "Bower install failed"; return ${exit_status}; }
    fi
  fi

  if inArray "REQUIRED_TASKS" "unit"; then
    # Run unit tests - there should always be a task even if it does nothing. Checking for pytest.ini file first.
    if [[ -f pytest.ini ]]; then
      info "Running unit tests with pytest..."
      MANAGE_OPTIONS=""
      if [[ -n ${UNIT_OPTIONS} ]]; then
        MANAGE_OPTIONS+=" ${UNIT_OPTIONS}"
      fi
      python pytest ${MANAGE_OPTIONS} ||
        { exit_status=$?; fatal "Tests failed"; return ${exit_status}; }
    else
      if [[ -f manage.py ]]; then
        info "Running unit tests ..."
        MANAGE_OPTIONS=""
        if [[ -n ${TEST_REPORTS_DIR} ]]; then
          if [[ -n ${TEST_JUNIT_DIR} ]]; then
            # Set --junit-xml option if TEST_REPORTS_DIR and TEST_JUNIT_DIR are set
            MANAGE_OPTIONS+=" --junit-xml ${TEST_REPORTS_DIR}/${TEST_JUNIT_DIR}/unit-test-results.xml"
          fi
        fi
        if [[ -n ${UNIT_OPTIONS} ]]; then
          MANAGE_OPTIONS+=" ${UNIT_OPTIONS}"
        fi
        ENV_FILE=${PYTHON_UNIT_TEST_ENV_FILE} python manage.py test ${MANAGE_OPTIONS} ||
          { exit_status=$?; fatal "Tests failed"; return ${exit_status}; }
      else
        warning "No manage.py - no tests run"
      fi
    fi
  fi

  if inArray "REQUIRED_TASKS" "integration"; then
    # Run integration tests
    if [[ -f "${AUTOMATION_BUILD_DEVOPS_DIR}/docker-test/Dockerfile-test" ]]; then
      info "Running integration tests ..."
      cd ${AUTOMATION_BUILD_DEVOPS_DIR}/docker-test/
      ./scripts/runDockerComposeTests.sh ||
      { exit_status=$?; fatal "Integration tests failed"; return ${exit_status}; }
      cd ${AUTOMATION_BUILD_SRC_DIR}
    fi
  fi

  if inArray "REQUIRED_TASKS" "swagger"; then
    # Generate swagger documents
    if [[ -f manage.py ]]; then
      info "Generate swagger documents ..."

      MANAGE_OPTIONS=""
      if [[ -n ${SWAGGER_OPTIONS} ]]; then
        MANAGE_OPTIONS+=" ${SWAGGER_OPTIONS}"
      fi
      if [[ -n ${COMPONENT_INSTANCES} ]]; then
      # Iterate component instance list if it is specified. Case for the projects with different API channels.
      # COMPONENT_INSTANCE must be environment variable
        for COMPONENT_INSTANCE in ${COMPONENT_INSTANCES}; do
            # spec directory is on the same level with the build directory 
            SWAGGER_TARGET_FILE="${AUTOMATION_BUILD_DIR}"/../spec/${COMPONENT_INSTANCE}/swagger.yaml
            ENV_FILE=${PYTHON_SWAGGER_ENV_FILE} COMPONENT_INSTANCE=${COMPONENT_INSTANCE} python manage.py swagger ${SWAGGER_TARGET_FILE} ${MANAGE_OPTIONS} ||
              { exit_status=$?; fatal "Generate swagger documents failed"; return ${exit_status}; }
        done
      else
        SWAGGER_TARGET_FILE="${AUTOMATION_BUILD_DIR}"/../spec/swagger.yaml
        ENV_FILE=${PYTHON_SWAGGER_ENV_FILE} python manage.py swagger ${SWAGGER_TARGET_FILE} ${MANAGE_OPTIONS} ||
          { exit_status=$?; fatal "Generate swagger documents failed"; return ${exit_status}; }
      fi
      # set code reference to master if a
      [[ ! -n "${SWAGGER_CODE_REFERENCE}" ]] && SWAGGER_CODE_REFERENCE="master"
      save_product_code "swagger documents generated based on ${GIT_COMMIT}" "${SWAGGER_CODE_REFERENCE}"
    else
      warning "No manage.py"
    fi
  fi

  if inArray "REQUIRED_TASKS" "build"; then
    # Package for lambda if required
    for ZAPPA_DIR in "${AUTOMATION_BUILD_DEVOPS_DIR}/lambda" "./"; do
      if [[ -f "${ZAPPA_DIR}/zappa_settings.json" ]]; then
        info "Packaging for lambda ..."
        BUILD=$(zappa package default -s ${ZAPPA_DIR}/zappa_settings.json | tail -1 | cut -d' ' -f3)
        if [[ -f ${BUILD} ]]; then
          mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/dist"
          mv ${BUILD} "${AUTOMATION_BUILD_SRC_DIR}/dist/lambda.zip"
        else
          { exit_status=$?; fatal "Packaging for lambda failed"; return ${exit_status}; }
        fi
      fi
    done
  fi

  if inArray "REQUIRED_TASKS" "build|unit|swagger"; then
    # Clean up
    if [[ -f package.json ]]; then
      npm prune --production ||
        { exit_status=$?; fatal "npm prune failed"; return ${exit_status}; }
    fi

    # Clean up the virtual env
    [[ -d "${venv_dir}" ]] && rm -rf "${venv_dir}"
  fi

  # All good
  return 0
}

main "$@"

