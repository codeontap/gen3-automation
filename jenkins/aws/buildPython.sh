#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Is this really a python based project
if [[ ! -f requirements.txt ]]; then
   echo -e "\nNo requirements.txt - is this really a python base repo?" >&2
   RESULT=1
   exit
fi

# Set up the virtual build environment
virtualenv .venv
RESULT=$?
if [ ${RESULT} -ne 0 ]; then
   echo -e "\nCreation of virtual build environment failed" >&2
   exit
fi
. .venv/bin/activate

# Process requirements files
shopt -s nullglob
REQUIREMENTS_FILES=( requirements*.txt )
for REQUIREMENTS_FILE in "${REQUIREMENTS_FILES[@]}"; do
    pip install -r ${REQUIREMENTS_FILE} --upgrade
    RESULT=$?
    if [ ${RESULT} -ne 0 ]; then
       echo -e "\nInstallation of requirements failed" >&2
       exit
    fi
done

if [[ -f package.json ]]; then
    npm install --unsafe-perm
    RESULT=$?
    if [ ${RESULT} -ne 0 ]; then
       echo -e "\nnpm install failed" >&2
       exit
    fi
fi

# Run bower as part of the build if required
if [[ -f bower.json ]]; then
    bower install --allow-root
    RESULT=$?
    if [ ${RESULT} -ne 0 ]; then
       echo -e "\nbower install failed" >&2
       exit
    fi
fi

# Package for lambda if required
if [[ -f zappa_settings.json ]]; then
    BUILD=$(zappa package default | tail -1 | cut -d' ' -f3)
    if [[ -f ${BUILD} ]]; then
        mkdir -p dist/
        mv ${BUILD} dist/lambda.zip
    fi
fi

# Clean up
if [[ -f package.json ]]; then
    npm prune --production
    RESULT=$?
    if [ ${RESULT} -ne 0 ]; then
       echo -e "\nnpm prune failed" >&2
       exit
    fi
fi

${AUTOMATION_DIR}/manageImages.sh -g "${CODE_COMMIT_ARRAY[0]}" -u "${DEPLOYMENT_UNIT_ARRAY[0]}" -f "${IMAGE_FORMATS_ARRAY[0]}"
RESULT=$?
