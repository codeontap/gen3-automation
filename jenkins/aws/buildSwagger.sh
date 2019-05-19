#!/usr/bin/env bash

# Augment a swagger file with AWS API gateway integration semantics

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") && (-d "${tmpdir}") ]] && rm -rf "${tmpdir}";exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Define the desired result file
DIST_DIR="${AUTOMATION_BUILD_DIR}/dist"
mkdir -p ${DIST_DIR}
SWAGGER_RESULT_FILE="${DIST_DIR}/swagger.zip"

# We need to use a docker staging dir to provide docker-in-docker support
tmpdir="$(getTempDir "cota_swag_XXXXXX" "${DOCKER_STAGE_DIR}")"
chmod a+rwx "${tmpdir}"

TEMP_SWAGGER_SPEC_FILE="${tmpdir}/swagger.json"

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
                    "${AUTOMATION_BUILD_DIR}/../../../**/*spec/swagger.json" \
                    "${AUTOMATION_BUILD_DIR}/../**/*spec/${BUILD_DIR}/openapi.json" \
                    "${AUTOMATION_BUILD_DIR}/../../**/*spec/${BUILD_DIR}/openapi.json" \
                    "${AUTOMATION_BUILD_DIR}/../../../**/*spec/${BUILD_DIR}/openapi.json" \
                    "${AUTOMATION_BUILD_DIR}/openapi.json" \
                    "${AUTOMATION_BUILD_DIR}/../**/*spec/openapi.json" \
                    "${AUTOMATION_BUILD_DIR}/../../**/*spec/openapi.json" \
                    "${AUTOMATION_BUILD_DIR}/../../../**/*spec/openapi.json")
SWAGGER_SPEC_YAML_FILE=$(findFile \
                    "${AUTOMATION_BUILD_DIR}/../**/*spec/${BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../**/*spec/${BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../../**/*spec/${BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../**/*spec/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../**/*spec/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../../**/*spec/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../**/*spec/${BUILD_DIR}/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../**/*spec/${BUILD_DIR}/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../../**/*spec/${BUILD_DIR}/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR}/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../**/*spec/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../**/*spec/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR}/../../../**/*spec/openapi.yaml")
# TODO(mfl) Remove once confirmed it is not used - see comment below
# SWAGGER_SPEC_YAML_EXTENSIONS_FILE=$(findFile \
#                    "${AUTOMATION_BUILD_DIR}/swagger_extensions.yaml" \
#                    "${AUTOMATION_BUILD_DEVOPS_DIR}/swagger_extensions.yaml" \
#                    "${AUTOMATION_BUILD_DEVOPS_DIR}/codeontap/swagger_extensions.yaml" \
#                    "${AUTOMATION_BUILD_DIR}/openapi_extensions.yaml" \
#                    "${AUTOMATION_BUILD_DEVOPS_DIR}/openapi_extensions.yaml" \
#                    "${AUTOMATION_BUILD_DEVOPS_DIR}/codeontap/openapi_extensions.yaml")

# Make a local copy of the swagger json file and bundle in a single file
if [[ -f "${SWAGGER_SPEC_FILE}" ]]; then

    SWAGGER_SPEC_FILE_NAME="$(fileName "${SWAGGER_SPEC_FILE}")"
    SWAGGER_SPEC_FILE_DIR="$(filePath "${SWAGGER_SPEC_FILE}")"

    # Copy the swagger spec to a directory docker can get to
    cp -rp "${SWAGGER_SPEC_FILE_DIR}" "${tmpdir}/bundle"
    SWAGGER_SPEC_FILE_DIR="${tmpdir}/bundle"

    docker run --rm \
        -v "${SWAGGER_SPEC_FILE_DIR}:/app/indir" \
        -v "${tmpdir}:/app/outdir" \
        codeontap/utilities swagger-cli bundle \
        --outfile "/app/outdir/swagger.json" \
        "/app/indir/${SWAGGER_SPEC_FILE_NAME}" ||
      { exit_status=$?; fatal "Unable to bundle ${SWAGGER_SPEC_FILE}"; exit ${exit_status}; }
fi

# Convert yaml files to json after bundling into a single file
if [[ -f "${SWAGGER_SPEC_YAML_FILE}" ]]; then

    # TODO(mfl) Remove this commented out code once confirm functioj not used
    # The inclusion mechanism in operapi3 should be used in preference to this
    # home grown alternative
#    cp "${SWAGGER_SPEC_YAML_FILE}" "${TEMP_SWAGGER_SPEC_YAML_FILE}"
#    if [[ -f "${SWAGGER_SPEC_YAML_EXTENSIONS_FILE}" ]]; then
#        # Combine the two
#        cp "${TEMP_SWAGGER_SPEC_YAML_FILE}" "${tmpdir}/swagger_copy.yaml"
#        cp "${SWAGGER_SPEC_YAML_EXTENSIONS_FILE}" "${tmpdir}/swagger_extensions.yaml"
#        docker run --rm \
#            -v "${tmpdir}:/app/indir" -v "${tmpdir}:/app/outdir" \
#            codeontap/utilities sme merge \
#            /app/indir/swagger_copy.yaml \
#            /app/indir/swagger_extensions.yaml \
#            /app/outdir/$(fileName "${TEMP_SWAGGER_SPEC_YAML_FILE}")
#    fi

    # Bundle into single yaml file
    SWAGGER_SPEC_YAML_FILE_NAME="$(fileName "${SWAGGER_SPEC_YAML_FILE}")"
    SWAGGER_SPEC_YAML_FILE_DIR="$(filePath "${SWAGGER_SPEC_YAML_FILE}")"

    # Copy the swagger spec to a directory docker can get to
    cp -rp "${SWAGGER_SPEC_YAML_FILE_DIR}" "${tmpdir}/bundle"
    SWAGGER_SPEC_YAML_FILE_DIR="${tmpdir}/bundle"

    docker run --rm \
        -v "${SWAGGER_SPEC_YAML_FILE_DIR}:/app/indir" \
        -v "${tmpdir}:/app/outdir" \
        codeontap/utilities swagger-cli bundle \
        --outfile "/app/outdir/swagger.yaml" \
        "/app/indir/${SWAGGER_SPEC_YAML_FILE_NAME}" ||
      { exit_status=$?; fatal "Unable to bundle ${SWAGGER_SPEC_YAML_FILE}"; exit ${exit_status}; }

    # Need to use a yaml to json converter that preserves comments in YAML multi-line blocks, as
    # AWS uses these are directives in API Gateway templates
    COMBINE_COMMAND="import sys, yaml, json; json.dump(yaml.load(open('/app/indir/swagger.yaml','r')), open('/app/outdir/$(fileName ${TEMP_SWAGGER_SPEC_FILE})','w'), indent=4)"
    docker run --rm \
        -v "${tmpdir}:/app/indir" -v "${tmpdir}:/app/outdir" \
        codeontap/python-utilities \
        -c "${COMBINE_COMMAND}"
fi

[[ ! -f "${TEMP_SWAGGER_SPEC_FILE}" ]] && fatal "Can't find source swagger file" && exit 1

# Validate it
# We use swagger-cli because it supports openapi3 and bundling
VALIDATORS=( "swagger-cli validate /app/indir/$(fileName ${TEMP_SWAGGER_SPEC_FILE})" )
for VALIDATOR in "${VALIDATORS[@]}"; do
    docker run --rm -v "${tmpdir}:/app/indir" codeontap/utilities ${VALIDATOR} ||
      { exit_status=$?; fatal "Swagger file is not valid"; exit ${exit_status}; }
done

# Remove definitions in swagger file not supported by AWS
SWAGGER_EXTENDED_BASE_FILE="${tmpdir}/swagger-extended-base.json"

runJQ -f "${AUTOMATION_DIR}/cleanUpSwagger.jq" < "${TEMP_SWAGGER_SPEC_FILE}" > "${SWAGGER_EXTENDED_BASE_FILE}"

# Augment the swagger file if required
APIGW_CONFIG=$(findFile \
                "${AUTOMATION_BUILD_DIR}/apigw.json" \
                "${AUTOMATION_BUILD_DEVOPS_DIR}/apigw.json" \
                "${AUTOMATION_BUILD_DEVOPS_DIR}/codeontap/apigw.json")

if [[ -f "${APIGW_CONFIG}" ]]; then

    # Generate the swagger file
    ${GENERATION_DIR}/createExtendedSwaggerSpecification.sh \
        -s "${SWAGGER_EXTENDED_BASE_FILE}" \
        -o "${SWAGGER_RESULT_FILE}" \
        -i "${APIGW_CONFIG}"

    # Check generation was successful
    [[ ! -f "${SWAGGER_RESULT_FILE}" ]] &&
        fatal "Can't find generated swagger files. Were they generated successfully?" && exit 1
else
    zip -j "${SWAGGER_RESULT_FILE}" "${SWAGGER_EXTENDED_BASE_FILE}"
fi

# All good
RESULT=0
