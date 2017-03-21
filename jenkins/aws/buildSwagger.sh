#!/bin/bash

# Augment a swagger file with AWs APi gateway integration semantics
 
if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Generate a swagger file if required
if [[ -f apigw.json ]]; then
    mkdir -p dist
    cp apigw.json dist/swagger.json
fi

# All good
RESULT=0