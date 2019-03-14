#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

cd "${SEGMENT_SOLUTIONS_DIR}"

# Build up the additional enviroment variables required
ENVS=()
for i in "" $(seq 2 20); do
    ENV_NAME="TASK_ENV${i}"
    ENV_VALUE="TASK_VALUE${i}"
    if [[ -n "${!ENV_NAME}" ]]; then
        ENVS+=( "-e" "${!ENV_NAME}" "-v" "${!ENV_VALUE}")
    fi
done

# Determine the task list
TASK_LIST="${TASK_LIST:-$TASKS}"
TASK_LIST="${TASK_LIST:-$TASK}"

# run the required tasks
for CURRENT_TASK in $TASK_LIST; do
    ${GENERATION_DIR}/runTask.sh -t "${TASK_TIER}" -i "${TASK_COMPONENT}" -w "${CURRENT_TASK}" -x "${TASK_INSTANCE}" -y "${TASK_VERSION}" -c "${TASK_CONTAINER}" "${ENVS[@]}"
    RESULT=$?
    [[ ${RESULT} -ne 0 ]] &&
        fatal "Running of task ${CURRENT_TASK} failed" && exit $RESULT
done

# All good
RESULT=0
