#!/bin/bash

# Augment a swagger file with AWS API gateway integration semantics
 
if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Generate a swagger file if required
if [[ -f apigw.json ]]; then
    # Define the desired result file
    mkdir -p dist
    SWAGGER_RESULT_FILE="dist/swagger.json"

    if [[ -f swagger.yaml ]]; then
        SWAGGER_SPEC_FILE="temp_swagger.json"
        yaml2json swagger.yaml > "${SWAGGER_SPEC_FILE}"
    else
        SWAGGER_SPEC_FILE="swagger.json"
    fi
    
    if [[ ! -f "${SWAGGER_SPEC_FILE}" ]]; then
        echo -e "\nCan't find source swagger file" >&2
        exit
    fi
    
    # Generate the required integration boilerplate
    TEMPLATE="$(jq -c '.' apigw.json)"

    # TODO adjust next lines when path length limitations in jq are fixed
    INTEGRATIONS_FILTER="./temp_integrations.jq"
    cp ${AUTOMATION_DIR}/addAPIGatewayIntegrations.jq "${INTEGRATIONS_FILTER}"

    # Add integrations to the swagger file
    jq -f "${INTEGRATIONS_FILTER}" \
        --argjson template "${TEMPLATE}" \
        --arg noResponses true \
        "${SWAGGER_SPEC_FILE}" > "${SWAGGER_RESULT_FILE}"

    # Check generation was successful
    if [[ ! -f "${SWAGGER_RESULT_FILE}" ]]; then
        echo -e "\nCan't find generated swagger file. Was it generated successfully?" >&2
        exit
    fi
fi

# All good
RESULT=0