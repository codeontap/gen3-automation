#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

cd laravel/

/usr/local/bin/composer install --prefer-source --no-interaction
RESULT=$?
[[ $RESULT -ne 0 ]] && fatal "Composer install fails with the exit code $RESULT"

/usr/local/bin/composer update
RESULT=$?
[[ $RESULT -ne 0 ]] && fatal "Composer update fails with the exit code $RESULT"

cd ../

${AUTOMATION_DIR}/manageImages.sh
RESULT=$?
