#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

cd laravel/

/usr/local/bin/composer install --prefer-source --no-interaction
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\ncomposer install fails with the exit code $RESULT" >&2
   exit
fi

/usr/local/bin/composer update
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo -e "\ncomposer update fails with the exit code $RESULT" >&2
   exit
fi

cd ../

DEPLOYMENT_UNIT_ARRAY=(${DEPLOYMENT_UNIT_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})
IMAGE_FORMATS_ARRAY=(${IMAGE_FORMATS_LIST})
${AUTOMATION_DIR}/manageImages.sh -g "${CODE_COMMIT_ARRAY[0]}" -u "${DEPLOYMENT_UNIT_ARRAY[0]}" -f "${IMAGE_FORMATS_ARRAY[0]}"
RESULT=$?
