#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Formulate optional parameters
SNAPSHOT_OPTS=
if [[ -n "${SNAPSHOT_COUNT}" ]]; then
    SNAPSHOT_OPTS="${SNAPSHOT_OPTS} -r ${SNAPSHOT_COUNT}"
fi
if [[ -n "${SNAPSHOT_AGE}" ]]; then
    SNAPSHOT_OPTS="${SNAPSHOT_OPTS} -a ${SNAPSHOT_AGE}"
fi

# Snapshot the database
cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/solutions/${PRODUCT}/${SEGMENT}

${GENERATION_DIR}/snapshotRDSDatabase.sh -i ${COMPONENT} -s b${BUILD_NUMBER} ${SNAPSHOT_OPTS}
RESULT=$?

if [[ ${RESULT} -ne 0 ]]; then
	echo -e "\nSnapshot of ${SEGMENT}/${COMPONENT} failed"
	exit
fi

