#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

cd "${SEGMENT_SOLUTIONS_DIR}"

# run the required tasks

EXTRA_ARGS=""
if [[ -n "${PIPELINE_STATUS_ONLY}" ]]; then
        EXTRA_ARGS="${EXTRA_ARGS} -s"
fi

if [[ -n "${PIPELINE_ALLOW_CONCURRENT}" ]]; then 
        EXTRA_ARGS="${EXTRA_ARGS} -c"
fi

${GENERATION_DIR}/runPipeline.sh -t "${PIPELINE_TIER}" -i "${PIPELINE_COMPONENT}" -x "${PIPELINE_INSTANCE}" -y "${PIPELINE_VERSION}" $EXTRA_ARGS
RESULT=$?

if [[ ${RESULT} -ne 0 ]]; then 
        fatal "Running of pipepline ${PIPELINE_COMPONENT} - ${PIPELINE_INSTANCE} - ${PIPELINE_VERSION} failed" 
fi

# All good
RESULT="${RESULT:-0}"
