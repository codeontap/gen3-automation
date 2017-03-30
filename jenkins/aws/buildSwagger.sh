#!/bin/bash

# Augment a swagger file with AWS API gateway integration semantics
 
if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Generate a swagger file if required
if [[ -f "${AUTOMATION_BUILD_DIR}/apigw.json" ]]; then
    # Define the desired result file
    mkdir -p ${AUTOMATION_BUILD_DIR}/dist
    SWAGGER_RESULT_FILE="${AUTOMATION_BUILD_DIR}/dist/swagger.json"

    if [[ -f "${AUTOMATION_BUILD_DIR}/swagger.yaml" ]]; then
        SWAGGER_SPEC_FILE="${AUTOMATION_BUILD_DIR}/temp_swagger.json"
        yaml2json "${AUTOMATION_BUILD_DIR}/swagger.yaml" > "${SWAGGER_SPEC_FILE}"
    else
        SWAGGER_SPEC_FILE="${AUTOMATION_BUILD_DIR}/swagger.json"
    fi
    
    if [[ ! -f "${SWAGGER_SPEC_FILE}" ]]; then
        echo -e "\nCan't find source swagger file" >&2
        exit
    fi
    
    # Generate the swagger file in the context of the current environment
    cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT}/solutions/${SEGMENT}
    ${GENERATION_DIR}/createExtendedSwaggerSpecification.sh \
        -s "${SWAGGER_SPEC_FILE}" \
        -o "${SWAGGER_RESULT_FILE}" \
        -i "${AUTOMATION_BUILD_DIR}/apigw.json"

    # Check generation was successful
    if [[ ! -f "${SWAGGER_RESULT_FILE}" ]]; then
        echo -e "\nCan't find generated swagger file. Was it generated successfully?" >&2
        exit
    fi
fi

# All good
RESULT=0