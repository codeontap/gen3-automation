#!/bin/bash

# Augment a swagger file with AWS API gateway integration semantics
 
[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Define the desired result file
DIST_DIR="${AUTOMATION_BUILD_DIR}/dist"
mkdir -p ${DIST_DIR}
SWAGGER_RESULT_FILE="${DIST_DIR}/swagger.zip"

# Determine build dir in case of multiple specs in subdirs
BUILD_DIR="$(fileName "${AUTOMATION_BUILD_DIR}" )"

# Possible input files
SWAGGER_SPEC_FILE=$(findFile \
                    "${AUTOMATION_BUILD_DIR}/../**/*spec/${BUILD_DIR}/swagger.json" \
                    "${AUTOMATION_BUILD_DIR}/../../**/*spec/${BUILD_DIR}/swagger.json" \
                    "${AUTOMATION_BUILD_DIR}/../../../**/*spec/${BUILD_DIR}/swagger.json" \
                    "${AUTOMATION_BUILD_DIR}/swagger.json" \
                    "${AUTOMATION_BUILD_DIR}/../**/*spec/swagger.json" \
                    "${AUTOMATION_BUILD_DIR}/../../**/*spec/swagger.json" \
                    "${AUTOMATION_BUILD_DIR}/../../../**/*spec/swagger.json")
SWAGGER_SPEC_YAML_FILE=$(findFile \
                    "${AUTOMATION_BUILD_DIR}/../**/*spec/${BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../**/*spec/${BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../../**/*spec/${BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../**/*spec/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../**/*spec/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../../**/*spec/swagger.yaml")
SWAGGER_SPEC_YAML_EXTENSIONS_FILE=$(findFile \
                    "${AUTOMATION_BUILD_DIR}/swagger_extensions.yaml" \
                    "${AUTOMATION_BUILD_DEVOPS_DIR}/swagger_extensions.yaml" \
                    "${AUTOMATION_BUILD_DEVOPS_DIR}/codeontap/swagger_extensions.yaml")

# Make a local copy of the swagger json file
TEMP_SWAGGER_SPEC_FILE="${AUTOMATION_BUILD_DIR}/temp_swagger.json"
[[ -f "${SWAGGER_SPEC_FILE}" ]] && cp "${SWAGGER_SPEC_FILE}" "${TEMP_SWAGGER_SPEC_FILE}"

# Convert yaml files to json, possibly including a separate yaml based extensions file
TEMP_SWAGGER_SPEC_YAML_FILE="${AUTOMATION_BUILD_DIR}/temp_swagger.yaml"
if [[ -f "${SWAGGER_SPEC_YAML_FILE}" ]]; then
    cp "${SWAGGER_SPEC_YAML_FILE}" "${TEMP_SWAGGER_SPEC_YAML_FILE}"

    if [[ -f "${SWAGGER_SPEC_YAML_EXTENSIONS_FILE}" ]]; then
        # Combine the two
        cp "${TEMP_SWAGGER_SPEC_YAML_FILE}" "${AUTOMATION_BUILD_DIR}/temp_swagger_copy.yaml"
        cp "${SWAGGER_SPEC_YAML_EXTENSIONS_FILE}" "${AUTOMATION_BUILD_DIR}/temp_swagger_extensions_copy.yaml"
        docker run --rm \
            -v ${AUTOMATION_BUILD_DIR}:/app/indir -v ${AUTOMATION_BUILD_DIR}:/app/outdir \
            codeontap/utilities sme merge \
            /app/indir/temp_swagger_copy.yaml \
            /app/indir/temp_swagger_extensions_copy.yaml \
            /app/outdir/$(fileName "${TEMP_SWAGGER_SPEC_YAML_FILE}")
    fi

    # Need to use a yaml to json converter that preserves comments in YAML multi-line blocks, as
    # AWS uses these are directives in API Gateway templates
    COMBINE_COMMAND="import sys, yaml, json; json.dump(yaml.load(open('/app/indir/$(fileName ${TEMP_SWAGGER_SPEC_YAML_FILE})','r')), open('/app/outdir/$(fileName ${TEMP_SWAGGER_SPEC_FILE})','w'), indent=4)"
    docker run --rm \
        -v ${AUTOMATION_BUILD_DIR}:/app/indir -v ${AUTOMATION_BUILD_DIR}:/app/outdir \
        codeontap/python-utilities \
        -c "${COMBINE_COMMAND}"
fi

[[ ! -f "${TEMP_SWAGGER_SPEC_FILE}" ]] && fatal "Can't find source swagger file"

# Validate it
# We use a few different validators until we settle on a preferred one
VALIDATORS=( \
"swagger       validate /app/indir/$(fileName ${TEMP_SWAGGER_SPEC_FILE})" \
"swagger-tools validate /app/indir/$(fileName ${TEMP_SWAGGER_SPEC_FILE})" \
"ajv           validate -d /app/indir/$(fileName ${TEMP_SWAGGER_SPEC_FILE}) -s /usr/local/lib/node_modules/swagger-schema-official/schema.json")
for VALIDATOR in "${VALIDATORS[@]}"; do
    docker run --rm -v $(filePath "${TEMP_SWAGGER_SPEC_FILE}"):/app/indir codeontap/utilities ${VALIDATOR}
    RESULT=$?
    [[ "${RESULT}" -ne 0 ]] && fatal "Swagger file is not valid"
done

# Augment the swagger file if required
APIGW_CONFIG=$(findFile \
                "${AUTOMATION_BUILD_DIR}/apigw.json" \
                "${AUTOMATION_BUILD_DEVOPS_DIR}/apigw.json" \
                "${AUTOMATION_BUILD_DEVOPS_DIR}/codeontap/apigw.json")

if [[ -f "${APIGW_CONFIG}" ]]; then

    # Generate the swagger file
    ${GENERATION_DIR}/createExtendedSwaggerSpecification.sh \
        -s "${TEMP_SWAGGER_SPEC_FILE}" \
        -o "${SWAGGER_RESULT_FILE}" \
        -i "${APIGW_CONFIG}"

    # Check generation was successful
    [[ ! -f "${SWAGGER_RESULT_FILE}" ]] &&
        fatal "Can't find generated swagger files. Were they generated successfully?"
else
    zip "${SWAGGER_RESULT_FILE}" "${TEMP_SWAGGER_SPEC_FILE}"
fi

# Generate documentation
docker run --rm \
    -v $(filePath "${TEMP_SWAGGER_SPEC_FILE}"):/app/indir -v ${DIST_DIR}:/app/outdir \
    codeontap/utilities swagger2aglio \
     --input=/app/indir/$(fileName "${TEMP_SWAGGER_SPEC_FILE}") --output=/app/outdir/apidoc.html  \
     --theme-variables slate --theme-template triple
RESULT=$?
[[ "${RESULT}" -ne 0 ]] && fatal "Swagger file documentation generation failed"

# All good
RESULT=0