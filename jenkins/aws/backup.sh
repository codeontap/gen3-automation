#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

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
cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT}/solutions/${SEGMENT}

${GENERATION_DIR}/snapshotRDSDatabase.sh -s b${AUTOMATION_JOB_IDENTIFIER} ${SNAPSHOT_OPTS} "$@"
RESULT=$?

if [[ ${RESULT} -ne 0 ]]; then
	echo -e "\nSnapshot of ${SEGMENT} failed" >&2
	exit
fi

