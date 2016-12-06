#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Ensure RELEASE_IDENTIFIER have been provided
if [[ -z "${RELEASE_IDENTIFIER}" ]]; then
	echo -e "\nJob requires the identifier of the release to use in the deployment"
    exit
fi

# Ensure at least one slice has been provided
if [[ ( -z "${SLICE_LIST}" ) ]]; then
	echo -e "\nJob requires at least one slice"
    exit
fi

# Don't forget -c ${RELEASE_TAG} -i ${RELEASE_TAG} on constructTree.sh

# All good
RESULT=0

