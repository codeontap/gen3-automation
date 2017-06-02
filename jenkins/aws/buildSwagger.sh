#!/bin/bash

# Augment a swagger file with AWS API gateway integration semantics
 
if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Define the desired result file
DIST_DIR="${AUTOMATION_BUILD_DIR}/dist"
mkdir -p ${DIST_DIR}
SWAGGER_RESULT_FILE="${DIST_DIR}/swagger.json"

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

# Validate it
# We use a few different validators until we settle on a preferred one
VALIDATORS=( \
"swagger       validate /app/indir/${SWAGGER_SPEC_FILE##*/}" \
"swagger-tools validate /app/indir/${SWAGGER_SPEC_FILE##*/}" \
"ajv           validate -d /app/indir/${SWAGGER_SPEC_FILE##*/} -s /usr/local/lib/node_modules/swagger-schema-official/schema.json")
for VALIDATOR in "${VALIDATORS[@]}"; do
    docker run -v ${SWAGGER_SPEC_FILE%/*}:/app/indir codeontap/utilities ${VALIDATOR}
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo -e "\nSwagger file is not valid" >&2
        exit
    fi
done

# Augment the swagger file if required
APIGW_CONFIG="${AUTOMATION_BUILD_DIR}/apigw.json"
if [[ -f "${AUTOMATION_BUILD_DEVOPS_DIR}/codeontap/apigw.json" ]]; then
    APIGW_CONFIG="${AUTOMATION_BUILD_DEVOPS_DIR}/codeontap/apigw.json"
fi
if [[ -f "${APIGW_CONFIG}" ]]; then

    # Generate the swagger file in the context of the current environment
    cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}/config/${PRODUCT}/solutions/${SEGMENT}
    ${GENERATION_DIR}/createExtendedSwaggerSpecification.sh \
        -s "${SWAGGER_SPEC_FILE}" \
        -o "${SWAGGER_RESULT_FILE}" \
        -i "${APIGW_CONFIG}"

    # Check generation was successful
    if [[ ! -f "${SWAGGER_RESULT_FILE}" ]]; then
        echo -e "\nCan't find generated swagger file. Was it generated successfully?" >&2
        exit
    fi

else
    cp "${SWAGGER_SPEC_FILE}" "${SWAGGER_RESULT_FILE}"
fi

# Generate documentation
docker run --rm \
    -v ${SWAGGER_SPEC_FILE%/*}:/app/indir -v ${DIST_DIR}:/app/outdir \
    codeontap/utilities swagger2aglio \
     --input=/app/indir/${SWAGGER_SPEC_FILE##*/} --output=/app/outdir/apidoc.html  \
     --theme-variables slate --theme-template triple
RESULT=$?
if [[ "${RESULT}" -ne 0 ]]; then
    echo -e "\nSwagger file documentation generation failed" >&2
    exit
fi

# All good
RESULT=0