#!/bin/bash

# Augment a swagger file with AWS API gateway integration semantics
 
if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Define the desired result file
DIST_DIR="${AUTOMATION_BUILD_DIR}/dist"
mkdir -p ${DIST_DIR}
SWAGGER_RESULT_FILE="${DIST_DIR}/swagger.zip"

# Possible input files
SWAGGER_SPEC_FILE="${AUTOMATION_BUILD_DIR}/swagger.json"
SWAGGER_SPEC_YAML_FILE="${AUTOMATION_BUILD_DIR}/swagger.yaml"
SWAGGER_SPEC_YAML_EXTENSIONS_FILE="${AUTOMATION_BUILD_DIR}/swagger_extensions.yaml"
if [[ -f "${AUTOMATION_BUILD_DEVOPS_DIR}/codeontap/swagger_extensions.yaml" ]]; then
    SWAGGER_SPEC_YAML_EXTENSIONS_FILE="${AUTOMATION_BUILD_DEVOPS_DIR}/codeontap/swagger_extensions.yaml"
fi

# Convert yaml files to json, possibly including a separate yaml based extensions file
if [[ -f "${SWAGGER_SPEC_YAML_FILE}" ]]; then
    if [[ -f "${SWAGGER_SPEC_YAML_EXTENSIONS_FILE}" ]]; then
        # Combine the two
        cp "${SWAGGER_SPEC_YAML_EXTENSIONS_FILE}" "${AUTOMATION_BUILD_DIR}/temp_swagger_extensions.yaml"
        docker run --rm \
            -v ${AUTOMATION_BUILD_DIR}:/app/indir -v ${AUTOMATION_BUILD_DIR}:/app/outdir \
            codeontap/utilities sme merge \
            /app/indir/swagger.yaml \
            /app/indir/temp_swagger_extensions.yaml \
            /app/outdir/temp_swagger.yaml
        # Use the combined file
        SWAGGER_SPEC_YAML_FILE="${AUTOMATION_BUILD_DIR}/temp_swagger.yaml"       
    fi
    SWAGGER_SPEC_FILE="${AUTOMATION_BUILD_DIR}/temp_swagger.json"
    # Need to use a yaml to json converter that preserves comments in YAML multi-line blocks, as
    # AWS uses these are directives in API Gateway templates
    docker run --rm \
        -v ${AUTOMATION_BUILD_DIR}:/app/indir -v ${AUTOMATION_BUILD_DIR}:/app/outdir \
        codeontap/python-utilities \
        -c "import sys, yaml, json; json.dump(yaml.load(open('/app/indir/temp_swagger.yaml','r')), open('/app/outdir/temp_swagger.json','w'), indent=4)"
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
    docker run --rm -v ${SWAGGER_SPEC_FILE%/*}:/app/indir codeontap/utilities ${VALIDATOR}
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

    # Generate the swagger file
    ${GENERATION_DIR}/createExtendedSwaggerSpecification.sh \
        -s "${SWAGGER_SPEC_FILE}" \
        -o "${SWAGGER_RESULT_FILE}" \
        -i "${APIGW_CONFIG}"

    # Check generation was successful
    if [[ ! -f "${SWAGGER_RESULT_FILE}" ]]; then
        echo -e "\nCan't find generated swagger files. Were they generated successfully?" >&2
        exit
    fi

else
    zip "${SWAGGER_RESULT_FILE}" "${SWAGGER_SPEC_FILE}"
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