#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

cd "${SEGMENT_SOLUTIONS_DIR}"

ARGS=""

if [[ -n "${LAMBDA_INCLUDE_LOGS}" ]]; then 
    ARGS="${ARGS} -l"
fi

if [[ -n "${LAMBDA_INPUT_PAYLOAD}" ]]; then
    ARGS="${ARGS} -i \"${LAMBDA_INPUT_PAYLOAD}\""
fi 

# run the required tasks
${GENERATION_DIR}/runLambda.sh -u "${LAMBDA_DEPLOYMENT_UNIT}" -f "${LAMBDA_FUNCTION_ID}" "${ARGS}"
RESULT=$?
[[ ${RESULT} -ne 0 ]] &&
        fatal "Running of lambda ${LAMBDA_DEPLOYMENT_UNIT} failed" && exit $RESULT

# All good
RESULT=0
