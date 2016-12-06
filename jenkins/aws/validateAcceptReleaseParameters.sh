#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Ensure RELEASE_IDENTIFIER have been provided
if [[ -z "${RELEASE_IDENTIFIER}" ]]; then
	echo -e "\nJob requires the identifier of the release to be accepted"
    exit
fi

# Don't forget -c ${RELEASE_TAG} -i ${RELEASE_TAG} on constructTree.sh

# All good
RESULT=0


