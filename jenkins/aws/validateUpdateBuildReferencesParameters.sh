#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

[[ -z ${GIT_COMMIT} ]] &&
    fatal "This job requires a GIT_COMMIT value" && exit

# Ensure at least one deployment unit has been provided
[[ -z "${DEPLOYMENT_UNIT_LIST}" ]] &&
    fatal "Job requires at least one deployment unit" && exit

# Ensure at least one deployment unit has been provided
[[ ( -z "${IMAGE_FORMAT}" ) && ( -z "${IMAGE_FORMATS}" ) ]] &&
    fatal "Job requires the image format used to package the build" && exit


# All good
RESULT=0



