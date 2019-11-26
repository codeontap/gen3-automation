#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${GENERATION_BASE_DIR}/execution/common.sh"

# Formulate parameters - any provided to this script are also passed trhough
SNAPSHOT_OPTS=
if [[ -n "${SNAPSHOT_COUNT}" ]]; then
    SNAPSHOT_OPTS="${SNAPSHOT_OPTS} -r ${SNAPSHOT_COUNT}"
fi
if [[ -n "${SNAPSHOT_AGE}" ]]; then
    SNAPSHOT_OPTS="${SNAPSHOT_OPTS} -a ${SNAPSHOT_AGE}"
fi
if [[ -n "${COMPONENT}" ]]; then
    SNAPSHOT_OPTS="${SNAPSHOT_OPTS} -i ${COMPONENT}"
fi

# Snapshot the database
cd "${SEGMENT_SOLUTIONS_DIR}"

${GENERATION_DIR}/snapshotRDSDatabase.sh -s b${AUTOMATION_JOB_IDENTIFIER} ${SNAPSHOT_OPTS} "$@"
RESULT=$?
[[ ${RESULT} -ne 0 ]] && fatal "Snapshot of ${ENVIRONMENT}/${SEGMENT} failed"
