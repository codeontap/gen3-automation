#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT}/solutions/${SEGMENT}

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
    ${GENERATION_DIR}/runTask.sh -t "${TASK_TIER}" -i "${TASK_COMPONENT}" -w "${CURRENT_TASK}" "${ENVS[@]}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo -e "\nRunning of task ${CURRENT_TASK} failed"
        exit
    fi
done

# All good
RESULT=0


