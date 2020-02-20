#!/usr/bin/env bash

# Augment an openapi file with AWS API gateway integration semantics

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") && (-d "${tmpdir}") ]] && rm -rf "${tmpdir}";exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Determine the registry - it impacts some file names
IMAGE_FORMATS_ARRAY=(${IMAGE_FORMATS_LIST})
REGISTRY_TYPE="${IMAGE_FORMATS_ARRAY[0]}"

# We need to use a docker staging dir to provide docker-in-docker support
tmpdir="$(getTempDir "cota_swag_XXXXXX" "${DOCKER_STAGE_DIR}")"
chmod a+rwx "${tmpdir}"

# Determine build dir in case of multiple specs in subdirs
BUILD_DIR="$(fileName "${AUTOMATION_BUILD_DIR}" )"

# If a bundle context is provided, it defines the subtree in which the
# spec file can be located. The search for files thus needs to be limited
# to the bundle context if it is provided.
#
# The logic used may result in the repeated searching of the same directory if
# a bundle context is specified, but its a once off process and it keeps the
# search logic the same regardless of bundle context.
AUTOMATION_BUILD_DIR_PARENT="$(cd ${AUTOMATION_BUILD_DIR}/..; pwd)"
AUTOMATION_BUILD_DIR_GPARENT="$(cd ${AUTOMATION_BUILD_DIR}/../..; pwd)"
AUTOMATION_BUILD_DIR_GGPARENT="$(cd ${AUTOMATION_BUILD_DIR}/../../..; pwd)"
if [[ -n "${BUNDLE_CONTEXT_DIR}" ]]; then
    OPENAPI_BUNDLE_CONTEXT_DIR="${AUTOMATION_DATA_DIR}/${BUNDLE_CONTEXT_DIR}"

    if [[ "${AUTOMATION_BUILD_DIR_PARENT#${OPENAPI_BUNDLE_CONTEXT_DIR}}" == "${AUTOMATION_BUILD_DIR_PARENT}" ]]; then
        AUTOMATION_BUILD_DIR_PARENT="${OPENAPI_BUNDLE_CONTEXT_DIR}"
    fi
    if [[ "${AUTOMATION_BUILD_DIR_GPARENT#${OPENAPI_BUNDLE_CONTEXT_DIR}}" == "${AUTOMATION_BUILD_DIR_GPARENT}" ]]; then
        AUTOMATION_BUILD_DIR_GPARENT="${OPENAPI_BUNDLE_CONTEXT_DIR}"
    fi
    if [[ "${AUTOMATION_BUILD_DIR_GGPARENT#${OPENAPI_BUNDLE_CONTEXT_DIR}}" == "${AUTOMATION_BUILD_DIR_GGPARENT}" ]]; then
        AUTOMATION_BUILD_DIR_GGPARENT="${OPENAPI_BUNDLE_CONTEXT_DIR}"
    fi
fi

# Possible input files
OPENAPI_SPEC_FILE=$(findFile \
                    "${AUTOMATION_BUILD_DIR}/build/openapi.json" \
                    "${AUTOMATION_BUILD_DIR}/build/openapi.yml" \
                    "${AUTOMATION_BUILD_DIR}/build/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR}/build/swagger.json" \
                    "${AUTOMATION_BUILD_DIR}/build/swagger.yml" \
                    "${AUTOMATION_BUILD_DIR}/build/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/${BUILD_DIR}/openapi.json" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/${BUILD_DIR}/openapi.yml" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/${BUILD_DIR}/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/${BUILD_DIR}/swagger.json" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/${BUILD_DIR}/swagger.yml" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/${BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/${BUILD_DIR}/openapi.json" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/${BUILD_DIR}/openapi.yml" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/${BUILD_DIR}/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/${BUILD_DIR}/swagger.json" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/${BUILD_DIR}/swagger.yml" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/${BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/${BUILD_DIR}/openapi.json" \
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/${BUILD_DIR}/openapi.yml" \
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/${BUILD_DIR}/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/${BUILD_DIR}/swagger.json" \
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/${BUILD_DIR}/swagger.yml" \
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/${BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR}/openapi.json" \
                    "${AUTOMATION_BUILD_DIR}/openapi.yml" \
                    "${AUTOMATION_BUILD_DIR}/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR}/swagger.json" \
                    "${AUTOMATION_BUILD_DIR}/swagger.yml" \
                    "${AUTOMATION_BUILD_DIR}/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/openapi.json" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/openapi.yml" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/swagger.json" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/swagger.yml" \
                    "${AUTOMATION_BUILD_DIR_PARENT}/**/*spec/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/openapi.json" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/openapi.yml" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/openapi.yaml" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/swagger.json" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/swagger.yml" \
                    "${AUTOMATION_BUILD_DIR_GPARENT}/**/*spec/swagger.yaml" \
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/openapi.json" \
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/openapi.yml"\
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/openapi.yaml"\
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/swagger.json" \
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/swagger.yml" \
                    "${AUTOMATION_BUILD_DIR_GGPARENT}/**/*spec/swagger.yaml")

# Was a spec file found?
[[ ! -f "${OPENAPI_SPEC_FILE}" ]] && fatal "Can't find source openAPI file within the bundle context" && exit 1

# Bundle context if not explicitly defined starts where the spec file is
if [[ -z "${BUNDLE_CONTEXT_DIR}" ]]; then
    OPENAPI_BUNDLE_CONTEXT_DIR="$(filePath "${OPENAPI_SPEC_FILE}")"
fi

# Determine attributes of spec file
OPENAPI_SPEC_FILE_BASE="$(fileBase "${OPENAPI_SPEC_FILE}")"
OPENAPI_SPEC_FILE_EXTENSION="$(fileExtension "${OPENAPI_SPEC_FILE}")"
OPENAPI_SPEC_FILE_RELATIVE_PATH="${OPENAPI_SPEC_FILE#${OPENAPI_BUNDLE_CONTEXT_DIR}}"

# Collect the files that could be bundled
OPENAPI_BUNDLE_DIR="${tmpdir}/bundle"
mkdir "${OPENAPI_BUNDLE_DIR}"

pushd "${OPENAPI_BUNDLE_CONTEXT_DIR}" > /dev/null 2>&1
find . -name "*.json" -exec cp -p --parents {} "${OPENAPI_BUNDLE_DIR}" ";"
find . -name "*.yml"  -exec cp -p --parents {} "${OPENAPI_BUNDLE_DIR}" ";"
find . -name "*.yaml" -exec cp -p --parents {} "${OPENAPI_BUNDLE_DIR}" ";"
popd > /dev/null

# Bundle the spec file
TEMP_OPENAPI_SPEC_FILE="${tmpdir}/openapi.json"
docker run --rm \
    -v "${OPENAPI_BUNDLE_DIR}:/app/indir" \
    -v "${tmpdir}:/app/outdir" \
    codeontap/utilities swagger-cli bundle -r \
    --outfile "/app/outdir/openapi.${OPENAPI_SPEC_FILE_EXTENSION}" \
    "/app/indir/${OPENAPI_SPEC_FILE_RELATIVE_PATH}" ||
    { exit_status=$?; fatal "Unable to bundle ${OPENAPI_SPEC_FILE}"; exit ${exit_status}; }

# Convert yaml to json
case "${OPENAPI_SPEC_FILE_EXTENSION}" in
    yml|yaml)
        # Need to use a yaml to json converter that preserves comments in YAML multi-line blocks, as
        # AWS uses these are directives in API Gateway templates
        COMBINE_COMMAND="import sys, yaml, json; json.dump(yaml.load(open('/app/indir/openapi.${OPENAPI_SPEC_FILE_EXTENSION}','r')), open('/app/outdir/$(fileName ${TEMP_OPENAPI_SPEC_FILE})','w'), indent=4)"
        docker run --rm \
            -v "${tmpdir}:/app/indir" -v "${tmpdir}:/app/outdir" \
            codeontap/python-utilities \
            -c "${COMBINE_COMMAND}"
    ;;

esac

[[ ! -f "${TEMP_OPENAPI_SPEC_FILE}" ]] && fatal "Can't find source OpenAPI file" && exit 1

# Validate it
# We use swagger-cli because it supports openapi3 and bundling
VALIDATORS=( "swagger-cli validate /app/indir/$(fileName ${TEMP_OPENAPI_SPEC_FILE})" )
for VALIDATOR in "${VALIDATORS[@]}"; do
    docker run --rm -v "${tmpdir}:/app/indir" codeontap/utilities ${VALIDATOR} ||
      { exit_status=$?; fatal "OpenAPI file is not valid"; exit ${exit_status}; }
done

# Remove definitions in swagger file not supported by AWS
OPENAPI_EXTENDED_BASE_FILE="${tmpdir}/${REGISTRY_TYPE}-extended-base.json"

runJQ -f "${AUTOMATION_DIR}/cleanUpOpenapi.jq" < "${TEMP_OPENAPI_SPEC_FILE}" > "${OPENAPI_EXTENDED_BASE_FILE}"

# Augment the swagger file if required
APIGW_CONFIG=$(findFile \
                "${AUTOMATION_BUILD_DIR}/apigw.json" \
                "${AUTOMATION_BUILD_DEVOPS_DIR}/apigw.json" \
                "${AUTOMATION_BUILD_DEVOPS_DIR}/codeontap/apigw.json")

# Define the desired result file
DIST_DIR="${AUTOMATION_BUILD_DIR}/dist"
mkdir -p ${DIST_DIR}
OPENAPI_RESULT_FILE="${DIST_DIR}/${REGISTRY_TYPE}.zip"

if [[ -f "${APIGW_CONFIG}" ]]; then
    # Generate the swagger file
    ${GENERATION_DIR}/createExtendedSwaggerSpecification.sh \
        -s "${OPENAPI_EXTENDED_BASE_FILE}" \
        -o "${OPENAPI_RESULT_FILE}" \
        -i "${APIGW_CONFIG}"

    # Check generation was successful
    [[ ! -f "${OPENAPI_RESULT_FILE}" ]] &&
        fatal "Can't find generated openAPI files. Were they generated successfully?" && exit 1
else
    zip -j "${OPENAPI_RESULT_FILE}" "${OPENAPI_EXTENDED_BASE_FILE}"
fi

# All good
RESULT=0
