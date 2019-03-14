#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

cd "${SEGMENT_SOLUTIONS_DIR}"

# run the required tasks
${GENERATION_DIR}/runPipeline.sh -t "${PIPELINE_TIER}" -i "${PIPELINE_COMPONENT}" -x "${PIPELINE_INSTANCE}" -y "${PIPELINE_VERSION}" -c "${PIPELINE_CHECKONLY}"
RESULT=$?
[[ ${RESULT} -ne 0 ]] &&
        fatal "Running of pipepline ${PIPELINE_COMPONENT} - ${PIPELINE-INSTANCE} - ${PIPELINE_VERSION} failed" && exit $RESULT

# All good
RESULT=0
