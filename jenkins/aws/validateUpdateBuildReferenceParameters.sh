#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

if [[ -z ${GIT_COMMIT} ]]; then
  echo -e "\nThis job requires a GIT_COMMIT value"
  exit
fi

# Ensure at least one slice has been provided
if [[ ( -z "${SLICE_LIST}" ) ]]; then
	echo -e "\nJob requires at least one slice"
    exit
fi

# All good
RESULT=0



