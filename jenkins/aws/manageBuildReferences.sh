#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Defaults
REFERENCE_OPERATION_ACCEPT="accept"
REFERENCE_OPERATION_LIST="list"
REFERENCE_OPERATION_LISTFULL="listfull"
REFERENCE_OPERATION_UPDATE="update"
REFERENCE_OPERATION_VERIFY="verify"
REFERENCE_OPERATION_DEFAULT="${REFERENCE_OPERATION_LIST}"

function usage() {
    cat <<EOF

Manage build references for one or more deployment units

Usage: $(basename $0)  -f -l -u
                        -s DEPLOYMENT_UNIT_LIST
                        -g SEGMENT_BUILDS_DIR
                        -c CODE_COMMIT_LIST
                        -t CODE_TAG_LIST
                        -r CODE_REPO_LIST
                        -o REGISTRY_SCOPE
                        -p CODE_PROVIDER_LIST
                        -i IMAGE_FORMATS_LIST
                        -a ACCEPTANCE_TAG
                        -v VERIFICATION_TAG
where
(o) -a ACCEPTANCE_TAG (REFERENCE_OPERATION=${REFERENCE_OPERATION_ACCEPT}) to tag all builds as accepted
(o) -c CODE_COMMIT_LIST             is the commit for each deployment unit
(o) -f (REFERENCE_OPERATION=${REFERENCE_OPERATION_LISTFULL}) to detail full build info
(o) -g SEGMENT_BUILDS_DIR            is the segment builds directory tree to be managed
    -h                              shows this text
(o) -i IMAGE_FORMATS_LIST           is the list of image formats for each deployment unit
(o) -l (REFERENCE_OPERATION=${REFERENCE_OPERATION_LIST}) to detail DEPLOYMENT_UNIT_LIST build info
(o) -o REGISTRY_SCOPE               is the registry scope
(o) -p CODE_PROVIDER_LIST           is the repo provider for each deployment unit
(o) -r CODE_REPO_LIST               is the repo for each deployment unit
(m) -s DEPLOYMENT_UNIT_LIST         is the list of deployment units to process
(o) -t CODE_TAG_LIST                is the tag for each deployment unit
(o) -u (REFERENCE_OPERATION=${REFERENCE_OPERATION_UPDATE}) to update build references
(o) -v VERIFICATION_TAG (REFERENCE_OPERATION=${REFERENCE_OPERATION_VERIFY}) to verify build references

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

REFERENCE_OPERATION = ${REFERENCE_OPERATION_DEFAULT}

NOTES:

1. Appsettings directory must include segment directory
2. If there is no commit for a deployment unit, CODE_COMMIT_LIST must contain a "?"
3. If there is no repo for a deployment unit, CODE_REPO_LIST must contain a "?"
4. If there is no tag for a deployment unit, CODE_TAG_LIST must contain a "?"
5. Lists can be shorter than the DEPLOYMENT_UNIT_LIST. If shorter, they
   are padded with "?" to match the length of DEPLOYMENT_UNIT_LIST

EOF
    exit
}

# Update DETAIL_MESSAGE with build information
# $1 = deployment unit
# $2 = build commit (? = no commit)
# $3 = build tag (? = no tag)
# $4 = image formats (? = not provided)
function updateDetail() {
    local UD_DEPLOYMENT_UNIT="${1,,}"
    local UD_COMMIT="${2,,:-?}"
    local UD_TAG="${3:-?}"
    local UD_FORMATS="${4,,:-?}"

    if [[ ("${UD_COMMIT}" != "?") || ("${UD_TAG}" != "?") ]]; then
        DETAIL_MESSAGE="${DETAIL_MESSAGE}, ${UD_DEPLOYMENT_UNIT}="
        if [[ "${UD_FORMATS}" != "?" ]]; then
            DETAIL_MESSAGE="${DETAIL_MESSAGE}${UD_FORMATS}:"
        fi
        if [[ "${UD_TAG}" != "?" ]]; then
            # Format is tag then commit if provided
            DETAIL_MESSAGE="${DETAIL_MESSAGE}${UD_TAG}"
            if [[ "${UD_COMMIT}" != "?" ]]; then
                DETAIL_MESSAGE="${DETAIL_MESSAGE} (${UD_COMMIT:0:7})"
            fi
        else
            # Format is just the commit
            DETAIL_MESSAGE="${DETAIL_MESSAGE}${UD_COMMIT:0:7}"
        fi
    fi
}

# Extract parts of a build reference
# The legacy format uses a space separated, fixed position parts
# The current format uses JSON with parts as attributes
# $1 = build reference
function getBuildReferenceParts() {
    local GBRP_REFERENCE="${1}"
    local ATTRIBUTE=

    if [[ "${GBRP_REFERENCE}" =~ ^\{ ]]; then
        # Newer JSON based format
        for ATTRIBUTE in commit tag format; do
            ATTRIBUTE_VALUE=$(jq -r ".${ATTRIBUTE} | select(.!=null)" <<< "${GBRP_REFERENCE}")
            if [[ -z "${ATTRIBUTE_VALUE}" ]]; then
                ATTRIBUTE_VALUE=$(jq -r ".${ATTRIBUTE^} | select(.!=null)" <<< "${GBRP_REFERENCE}")
            fi
            declare -g "BUILD_REFERENCE_${ATTRIBUTE^^}"="${ATTRIBUTE_VALUE:-?}"
        done
        for ATTRIBUTE in formats; do
            readarray -t FORMAT_VALUES < <(jq -r ".${ATTRIBUTE} | select(.!=null) | .[]" <<< "${GBRP_REFERENCE}")
            arrayIsEmpty FORMAT_VALUES &&
                readarray -t FORMAT_VALUES < <(jq -r ".${ATTRIBUTE^} | select(.!=null) | .[]" <<< "${GBRP_REFERENCE}")
            ATTRIBUTE_VALUE="$(listFromArray FORMAT_VALUES "${IMAGE_FORMAT_SEPARATORS:0:1}")"
            declare -g "BUILD_REFERENCE_${ATTRIBUTE^^}"="${ATTRIBUTE_VALUE:-?}"
        done
        if [[ "${BUILD_REFERENCE_FORMATS}" == "?" ]]; then
            BUILD_REFERENCE_FORMATS="${BUILD_REFERENCE_FORMAT}"
        fi
    else
        BUILD_REFERENCE_ARRAY=(${GBRP_REFERENCE})
        BUILD_REFERENCE_COMMIT="${BUILD_REFERENCE_ARRAY[0]:-?}"
        BUILD_REFERENCE_TAG="${BUILD_REFERENCE_ARRAY[1]:-?}"
        BUILD_REFERENCE_FORMATS="?"
    fi
}

# Format a JSON based build reference
# $1 = build commit
# $2 = build tag (? = no tag)
# $3 = formats (default is docker)
function formatBuildReference() {
    local FBR_COMMIT="${1,,}"
    local FBR_TAG="${2:-?}"
    local FBR_FORMATS="${3,,:-?}"
    local FBR_SCOPE="${4,,:-?}"

    BUILD_REFERENCE="{\"Commit\": \"${FBR_COMMIT}\""
    if [[ "${FBR_TAG}" != "?" ]]; then
        BUILD_REFERENCE="${BUILD_REFERENCE}, \"Tag\": \"${FBR_TAG}\""
    fi
    if [[ "${FBR_SCOPE}" != "?" ]]; then
        BUILD_REFERENCE="${BUILD_REFERENCE}, \"Scope\": \"${FBR_SCOPE}\""
    fi
    if [[ "${FBR_FORMATS}" == "?" ]]; then
        FBR_FORMATS="docker"
    fi
    IFS="${IMAGE_FORMAT_SEPARATORS}" read -ra FBR_FORMATS_ARRAY <<< "${FBR_FORMATS}"
    BUILD_REFERENCE="${BUILD_REFERENCE}, \"Formats\": [\"${FBR_FORMATS_ARRAY[0]}\""
    for ((FORMAT_INDEX=1; FORMAT_INDEX<${#FBR_FORMATS_ARRAY[@]}; FORMAT_INDEX++)); do
        BUILD_REFERENCE="${BUILD_REFERENCE},\"${FBR_FORMATS_ARRAY[$FORMAT_INDEX]}\""
    done
    BUILD_REFERENCE="${BUILD_REFERENCE} ]}"
}

# Define git provider attributes
# $1 = provider
# $2 = variable prefix
function defineGitProviderAttributes() {
    local DGPA_PROVIDER="${1^^}"
    local DGPA_PREFIX="${2^^}"

    # Attribute variable names
    for DGPA_ATTRIBUTE in "DNS" "API_DNS" "ORG" "CREDENTIALS_VAR"; do
        DGPA_PROVIDER_VAR="${DGPA_PROVIDER}_GIT_${DGPA_ATTRIBUTE}"
        declare -g ${DGPA_PREFIX}_${DGPA_ATTRIBUTE}="${!DGPA_PROVIDER_VAR}"
    done
}

# Parse options
while getopts ":a:c:fg:hi:lo:p:r:s:t:uv:z:" opt; do
    case $opt in
        a)
            REFERENCE_OPERATION="${REFERENCE_OPERATION_ACCEPT}"
            ACCEPTANCE_TAG="${OPTARG}"
            ;;
        c)
            CODE_COMMIT_LIST="${OPTARG}"
            ;;
        f)
            REFERENCE_OPERATION="${REFERENCE_OPERATION_LISTFULL}"
            ;;
        g)
            SEGMENT_BUILDS_DIR="${OPTARG}"
            ;;
        h)
            usage
            ;;
        i)
            IMAGE_FORMATS_LIST="${OPTARG}"
            ;;
        l)
            REFERENCE_OPERATION="${REFERENCE_OPERATION_LIST}"
            ;;
        o)
            REGISTRY_SCOPE="${OPTARG}"
            ;;
        p)
            CODE_PROVIDER_LIST="${OPTARG}"
            ;;
        r)
            CODE_REPO_LIST="${OPTARG}"
            ;;
        s)
            DEPLOYMENT_UNIT_LIST="${OPTARG}"
            ;;
        t)
            CODE_TAG_LIST="${OPTARG}"
            ;;
        u)
            REFERENCE_OPERATION="${REFERENCE_OPERATION_UPDATE}"
            ;;
        v)
            REFERENCE_OPERATION="${REFERENCE_OPERATION_VERIFY}"
            VERIFICATION_TAG="${OPTARG}"
            ;;
        \?)
            fatalOption; exit
            ;;
        :)
            fatalOptionArgument; exit
            ;;
     esac
done

# Apply defaults
REFERENCE_OPERATION="${REFERENCE_OPERATION:-${REFERENCE_OPERATION_DEFAULT}}"

# Ensure mandatory arguments have been provided
case ${REFERENCE_OPERATION} in
    ${REFERENCE_OPERATION_ACCEPT})
        # Add the acceptance tag on provided deployment unit list
        # Normally this would be called after list full
        [[ (-z "${DEPLOYMENT_UNIT_LIST}") ||
            (-z "${ACCEPTANCE_TAG}") ]] && fatalMandatory && exit
        ;;

    ${REFERENCE_OPERATION_LIST})
        # Format the build details based on provided deployment unit list
        [[ (-z "${DEPLOYMENT_UNIT_LIST}") ]] && fatalMandatory && exit
        ;;

    ${REFERENCE_OPERATION_LISTFULL})
        # Populate DEPLOYMENT_UNIT_LIST based on current appsettings
        [[ -z "${SEGMENT_BUILDS_DIR}" ]] && fatalMandatory && exit
        ;;

    ${REFERENCE_OPERATION_UPDATE})
        # Update builds based on provided deployment unit list
        [[ (-z "${DEPLOYMENT_UNIT_LIST}") ||
            (-z "${SEGMENT_BUILDS_DIR}") ]] && fatalMandatory && exit
        ;;

    ${REFERENCE_OPERATION_VERIFY})
        # Verify builds based on provided deployment unit list
        [[ (-z "${DEPLOYMENT_UNIT_LIST}") ||
            (-z "${VERIFICATION_TAG}") ]] && fatalMandatory && exit
        ;;

    *)
        fatal "Invalid REFERENCE_OPERATION \"${REFERENCE_OPERATION}\"" && exit
        ;;
esac


# Access existing build info
DEPLOYMENT_UNIT_ARRAY=(${DEPLOYMENT_UNIT_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})
CODE_TAG_ARRAY=(${CODE_TAG_LIST})
CODE_REPO_ARRAY=(${CODE_REPO_LIST})
CODE_PROVIDER_ARRAY=(${CODE_PROVIDER_LIST})
IMAGE_FORMATS_ARRAY=(${IMAGE_FORMATS_LIST})

if [[ -n "${SEGMENT_BUILDS_DIR}" ]]; then
    # Most operations require access to the segment build settings
    mkdir -p ${SEGMENT_BUILDS_DIR}
    cd ${SEGMENT_BUILDS_DIR}
fi

if [[ ("${REFERENCE_OPERATION}" == "${REFERENCE_OPERATION_LISTFULL}") ]]; then
    # Update the deployment unit list with all deployment units
    DEPLOYMENT_UNIT_ARRAY=()
    for BUILD_FILE in $(find . -name "build.*"); do
        DEPLOYMENT_UNIT_ARRAY+=("$(basename $(dirname ${BUILD_FILE}))")
    done
fi

# Process each deployment unit
for ((INDEX=0; INDEX<${#DEPLOYMENT_UNIT_ARRAY[@]}; INDEX++)); do

    # Next deployment unit to process
    CURRENT_DEPLOYMENT_UNIT="${DEPLOYMENT_UNIT_ARRAY[${INDEX}]}"
    CODE_COMMIT="${CODE_COMMIT_ARRAY[${INDEX}]:-?}"
    CODE_TAG="${CODE_TAG_ARRAY[${INDEX}]:-?}"
    CODE_REPO="${CODE_REPO_ARRAY[${INDEX}]:-?}"
    CODE_PROVIDER="${CODE_PROVIDER_ARRAY[${INDEX}]:-?}"
    IMAGE_FORMATS="${IMAGE_FORMATS_ARRAY[${INDEX}]:-?}"
    IFS="${IMAGE_FORMAT_SEPARATORS}" read -ra CODE_IMAGE_FORMATS_ARRAY <<< "${IMAGE_FORMATS}"

    # Look for the deployment unit and build reference files
    BUILD_FILE="${CURRENT_DEPLOYMENT_UNIT}/build.json"

    # Allow for building a new build.json with a reference to a shared build
    SHARED_BUILD_FILE="${CURRENT_DEPLOYMENT_UNIT}/shared_build.json"
    if [[ -f "${SHARED_BUILD_FILE}" ]]; then
        REGISTRY_DEPLOYMENT_UNIT="$(jq -r '.Reference' < ${SHARED_BUILD_FILE})"
    else
        REGISTRY_DEPLOYMENT_UNIT="${CURRENT_DEPLOYMENT_UNIT}"
    fi

    # Ensure appsettings directories exist
    if [[ -n "${SEGMENT_BUILDS_DIR}" ]]; then
        mkdir -p "${CURRENT_DEPLOYMENT_UNIT}"
    fi

    case ${REFERENCE_OPERATION} in
        ${REFERENCE_OPERATION_ACCEPT})
            # Tag builds with an acceptance tag
            if [[ "${IMAGE_FORMATS}" != "?" ]]; then
                for IMAGE_FORMAT in "${CODE_IMAGE_FORMATS_ARRAY[@]}"; do
                    IMAGE_PROVIDER_VAR="PRODUCT_${IMAGE_FORMAT^^}_PROVIDER"
                    IMAGE_PROVIDER="${!IMAGE_PROVIDER_VAR}"
                    IMAGE_FORMAT_LOWER=${IMAGE_FORMAT,,}
                    case ${IMAGE_FORMAT_LOWER} in
                        docker)
                            ${AUTOMATION_DIR}/manage${IMAGE_FORMAT_LOWER^}.sh -k \
                                -a "${IMAGE_PROVIDER}" \
                                -s "${REGISTRY_DEPLOYMENT_UNIT}" \
                                -g "${CODE_COMMIT}" \
                                -r "${ACCEPTANCE_TAG}" \
                                -c "${REGISTRY_SCOPE}"
                            RESULT=$?
                            [[ "${RESULT}" -ne 0 ]] && exit
                            ;;
                        lambda|spa|contentnode|scripts|pipeline|dataset|rdssnapshot)
                            ${AUTOMATION_DIR}/manage${IMAGE_FORMAT_LOWER^}.sh -k \
                                -a "${IMAGE_PROVIDER}" \
                                -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                                -g "${CODE_COMMIT}" \
                                -r "${ACCEPTANCE_TAG}" \
                                -c "${REGISTRY_SCOPE}"
                            RESULT=$?
                            [[ "${RESULT}" -ne 0 ]] && exit
                            ;;
                        openapi|swagger)
                            ${AUTOMATION_DIR}/manageOpenapi.sh -k
                                -a "${IMAGE_PROVIDER}" \
                                -y "${IMAGE_FORMAT_LOWER}"
                                -f "${IMAGE_FORMAT_LOWER}.zip" \
                                -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                                -g "${CODE_COMMIT}" \
                                -r "${ACCEPTANCE_TAG}" \
                                -c "${REGISTRY_SCOPE}"
                            RESULT=$?
                            [[ "${RESULT}" -ne 0 ]] && exit
                            ;;
                        *)
                            fatal "Unknown image format \"${IMAGE_FORMAT}\"" && exit
                            ;;
                    esac
                done
            fi
            ;;

        ${REFERENCE_OPERATION_LIST})
            # Add build info to DETAIL_MESSAGE
            updateDetail "${CURRENT_DEPLOYMENT_UNIT}" "${CODE_COMMIT}" "${CODE_TAG}" "${IMAGE_FORMATS}"
            ;;

        ${REFERENCE_OPERATION_LISTFULL})
            if [[ -f ${BUILD_FILE} && ! -f ${SHARED_BUILD_FILE} ]]; then
                getBuildReferenceParts "$(cat ${BUILD_FILE})"
                if [[ "${BUILD_REFERENCE_COMMIT}" != "?" ]]; then
                    # Update arrays
                    CODE_COMMIT_ARRAY["${INDEX}"]="${BUILD_REFERENCE_COMMIT}"
                    CODE_TAG_ARRAY["${INDEX}"]="${BUILD_REFERENCE_TAG}"
                    IMAGE_FORMATS_ARRAY["${INDEX}"]="${BUILD_REFERENCE_FORMATS}"
                fi
            fi
            ;;

        ${REFERENCE_OPERATION_UPDATE})
            # Ensure something to do for the current deployment unit
            if [[ "${CODE_COMMIT}" == "?" ]]; then continue; fi

            # Preserve the format if none provided
            if [[ ("${IMAGE_FORMATS}" == "?") &&
                    (-f ${BUILD_FILE}) ]]; then
                getBuildReferenceParts "$(cat ${BUILD_FILE})"
                IMAGE_FORMATS="${BUILD_REFERENCE_FORMATS}"
            fi

            # Construct the build reference
            formatBuildReference "${CODE_COMMIT}" "${CODE_TAG}" "${IMAGE_FORMATS}" "${REGISTRY_SCOPE}"

            # Update the build reference
            # Use newer naming and clean up legacy named build reference files
            echo -n "${BUILD_REFERENCE}" > "${BUILD_FILE}"
            ;;

        ${REFERENCE_OPERATION_VERIFY})
            # Ensure code repo defined if tag provided only if commit not provided
            if [[ "${CODE_COMMIT}" == "?" ]]; then
                if [[ "${CODE_TAG}" != "?" ]]; then
                    if [[ ("${CODE_REPO}" == "?") ||
                            ("${CODE_PROVIDER}" == "?") ]]; then
                        fatal "Ignoring tag for the \"${CURRENT_DEPLOYMENT_UNIT}\" deployment unit - no code repo and/or provider defined" && exit
                    fi
                    # Determine the details of the provider hosting the code repo
                    defineGitProviderAttributes "${CODE_PROVIDER}" "CODE"
                    # Get the commit corresponding to the tag
                    TAG_COMMIT=$(git ls-remote -t https://${!CODE_CREDENTIALS_VAR}@${CODE_DNS}/${CODE_ORG}/${CODE_REPO} \
                                    "${CODE_TAG}" | cut -f 1)
                    CODE_COMMIT=$(git ls-remote -t https://${!CODE_CREDENTIALS_VAR}@${CODE_DNS}/${CODE_ORG}/${CODE_REPO} \
                                    "${CODE_TAG}^{}" | cut -f 1)
                    [[ -z "${CODE_COMMIT}" ]] &&
                        fatal "Tag ${CODE_TAG} not found in the ${CODE_REPO} repo. Was an annotated tag used?" && exit

                    # Fetch other info about the tag
                    # We are using a github api here to avoid having to pull in the whole repo -
                    # git currently doesn't have a command to query the message of a remote tag
                    CODE_TAG_MESSAGE=$(curl -s https://${!CODE_CREDENTIALS_VAR}@${CODE_API_DNS}/repos/${CODE_ORG}/${CODE_REPO}/git/tags/${TAG_COMMIT} | jq .message | tr -d '"')
                    [[ (-z "${CODE_TAG_MESSAGE}") ||
                        ("${CODE_TAG_MESSAGE}" == "Not Found") ]] &&
                        fatal "Message for tag ${CODE_TAG} not found in the ${CODE_REPO} repo" && exit
                    # else
                    # TODO: Confirm commit is in remote repo - for now we'll assume its there if an image exists
                else
                    # Nothing to do for this deployment unit
                    # Note that it is permissible to not have a tag for a deployment unit
                    # that is associated with a code repo. This situation arises
                    # if application settings are changed and a new release is
                    # thus required.
                    continue
                fi
            fi

            # If no formats explicitly defined, use those in the build reference if defined
            if [[ ("${IMAGE_FORMATS}" == "?") &&
                    (-f ${BUILD_FILE}) ]]; then
                getBuildReferenceParts "$(cat ${BUILD_FILE})"
                IMAGE_FORMATS="${BUILD_REFERENCE_FORMATS}"
                IFS="${IMAGE_FORMAT_SEPARATORS}" read -ra CODE_IMAGE_FORMATS_ARRAY <<< "${IMAGE_FORMATS}"
            fi

            # If we don't know the image type, then there is a problem
            # Most likely it is the first time this unit has been mentioned and no format was
            # included as part of the prepare operation.
            [[ "${IMAGE_FORMATS}" == "?" ]] &&
                        fatal "Image format(s) not known for \"${CURRENT_DEPLOYMENT_UNIT}\" deployment unit. Provide the format after the code reference separated by \"!\" if unit is being mentioned for the first time." && exit

            for IMAGE_FORMAT in "${CODE_IMAGE_FORMATS_ARRAY[@]}"; do
                IMAGE_PROVIDER_VAR="PRODUCT_${IMAGE_FORMAT^^}_PROVIDER"
                IMAGE_PROVIDER="${!IMAGE_PROVIDER_VAR}"
                FROM_IMAGE_PROVIDER_VAR="FROM_PRODUCT_${IMAGE_FORMAT^^}_PROVIDER"
                FROM_IMAGE_PROVIDER="${!FROM_IMAGE_PROVIDER_VAR}"
                case ${IMAGE_FORMAT,,} in
                    dataset)
                        ${AUTOMATION_DIR}/manageDataSetS3.sh -v \
                            -a "${IMAGE_PROVIDER}" \
                            -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                            -g "${CODE_COMMIT}" \
                            -c "${REGISTRY_SCOPE}"
                        RESULT=$?
                        ;;
                    rdssnapshot)
                        ${AUTOMATION_DIR}/manageDataSetRDSSnapshot.sh -v \
                            -a "${IMAGE_PROVIDER}" \
                            -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                            -g "${CODE_COMMIT}" \
                            -c "${REGISTRY_SCOPE}"
                        RESULT=$?
                        ;;
                    docker)
                        ${AUTOMATION_DIR}/manageDocker.sh -v \
                            -a "${IMAGE_PROVIDER}" \
                            -s "${REGISTRY_DEPLOYMENT_UNIT}" \
                            -g "${CODE_COMMIT}" \
                            -c "${REGISTRY_SCOPE}"
                        RESULT=$?
                        ;;
                    lambda)
                        ${AUTOMATION_DIR}/manageLambda.sh -v \
                            -a "${IMAGE_PROVIDER}" \
                            -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                            -g "${CODE_COMMIT}" \
                            -c "${REGISTRY_SCOPE}"
                        RESULT=$?
                        ;;
                    pipeline)
                        ${AUTOMATION_DIR}/managePipeline.sh -v \
                            -a "${IMAGE_PROVIDER}" \
                            -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                            -g "${CODE_COMMIT}" \
                            -c "${REGISTRY_SCOPE}"
                        RESULT=$?
                        ;;
                    scripts)
                        ${AUTOMATION_DIR}/manageScripts.sh -v \
                            -a "${IMAGE_PROVIDER}" \
                            -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                            -g "${CODE_COMMIT}" \
                            -c "${REGISTRY_SCOPE}"
                        RESULT=$?
                        ;;
                    openapi|swagger)
                        ${AUTOMATION_DIR}/manageOpenapi.sh -v \
                            -y "${IMAGE_FORMAT,,}" \
                            -f "${IMAGE_FORMAT,,}.zip" \
                            -a "${IMAGE_PROVIDER}" \
                            -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                            -g "${CODE_COMMIT}" \
                            -c "${REGISTRY_SCOPE}"
                        RESULT=$?
                        ;;
                    spa)
                        ${AUTOMATION_DIR}/manageSpa.sh -v \
                            -a "${IMAGE_PROVIDER}" \
                            -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                            -g "${CODE_COMMIT}" \
                            -c "${REGISTRY_SCOPE}"
                        RESULT=$?
                        ;;
                    contentnode)
                        ${AUTOMATION_DIR}/manageContentNode.sh -v \
                            -a "${IMAGE_PROVIDER}" \
                            -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                            -g "${CODE_COMMIT}" \
                            -c "${REGISTRY_SCOPE}"
                        RESULT=$?
                        ;;
                    *)
                        fatal "Unknown image format \"${IMAGE_FORMAT}\"" && exit
                        ;;
                esac
                if [[ "${RESULT}" -ne 0 ]]; then
                    if [[ -n "${FROM_IMAGE_PROVIDER}" ]]; then
                        # Attempt to pull image in from remote provider
                        case ${IMAGE_FORMAT,,} in
                            dataset)
                                ${AUTOMATION_DIR}/manageDataSetS3.sh -p \
                                    -a "${IMAGE_PROVIDER}" \
                                    -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                                    -g "${CODE_COMMIT}" \
                                    -r "${VERIFICATION_TAG}" \
                                    -z "${FROM_IMAGE_PROVIDER}" \
                                    -b "REGISTRY_CONTENT" \
                                    -c "${REGISTRY_SCOPE}"
                                RESULT=$?
                                ;;
                            rdssnapshot)
                                ${AUTOMATION_DIR}/manageDataSetRDSSnapshot.sh -p \
                                    -a "${IMAGE_PROVIDER}" \
                                    -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                                    -r "${VERIFICATION_TAG}" \
                                    -z "${FROM_IMAGE_PROVIDER}" \
                                    -g "${CODE_COMMIT}" \
                                    -c "${REGISTRY_SCOPE}"
                                RESULT=$?
                                ;;
                            docker)
                                ${AUTOMATION_DIR}/manageDocker.sh -p \
                                    -a "${IMAGE_PROVIDER}" \
                                    -s "${REGISTRY_DEPLOYMENT_UNIT}" \
                                    -g "${CODE_COMMIT}" \
                                    -r "${VERIFICATION_TAG}" \
                                    -z "${FROM_IMAGE_PROVIDER}" \
                                    -c "${REGISTRY_SCOPE}"
                                RESULT=$?
                                ;;
                            lambda)
                                ${AUTOMATION_DIR}/manageLambda.sh -p \
                                    -a "${IMAGE_PROVIDER}" \
                                    -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                                    -g "${CODE_COMMIT}" \
                                    -r "${VERIFICATION_TAG}" \
                                    -z "${FROM_IMAGE_PROVIDER}" \
                                    -c "${REGISTRY_SCOPE}"
                                RESULT=$?
                                ;;
                            pipeline)
                                ${AUTOMATION_DIR}/managePipeline.sh -p \
                                    -a "${IMAGE_PROVIDER}" \
                                    -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                                    -g "${CODE_COMMIT}" \
                                    -r "${VERIFICATION_TAG}" \
                                    -z "${FROM_IMAGE_PROVIDER}" \
                                    -c "${REGISTRY_SCOPE}"
                                RESULT=$?
                                ;;
                            scripts)
                                ${AUTOMATION_DIR}/manageScripts.sh -p \
                                    -a "${IMAGE_PROVIDER}" \
                                    -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                                    -g "${CODE_COMMIT}" \
                                    -r "${VERIFICATION_TAG}" \
                                    -z "${FROM_IMAGE_PROVIDER}" \
                                    -c "${REGISTRY_SCOPE}"
                                RESULT=$?
                                ;;
                            openapi|swagger)
                                ${AUTOMATION_DIR}/manageOpenapi.sh -x -p \
                                    -a "${IMAGE_PROVIDER}" \
                                    -y "${IMAGE_FORMAT,,}" \
                                    -f "${IMAGE_FORMAT,,}.zip" \
                                    -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                                    -g "${CODE_COMMIT}" \
                                    -r "${VERIFICATION_TAG}" \
                                    -z "${FROM_IMAGE_PROVIDER}" \
                                    -c "${REGISTRY_SCOPE}"
                                RESULT=$?
                                ;;
                            spa)
                                ${AUTOMATION_DIR}/manageSpa.sh -p \
                                    -a "${IMAGE_PROVIDER}" \
                                    -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                                    -g "${CODE_COMMIT}" \
                                    -r "${VERIFICATION_TAG}" \
                                    -z "${FROM_IMAGE_PROVIDER}" \
                                    -c "${REGISTRY_SCOPE}"
                                RESULT=$?
                                ;;
                            contentnode)
                                ${AUTOMATION_DIR}/manageContentNode.sh -v \
                                -a "${IMAGE_PROVIDER}" \
                                -u "${REGISTRY_DEPLOYMENT_UNIT}" \
                                -g "${CODE_COMMIT}" \
                                -c "${REGISTRY_SCOPE}"
                                RESULT=$?
                                ;;
                            *)
                                fatal "Unknown image format \"${IMAGE_FORMAT}\"" && exit
                                ;;
                        esac
                        [[ "${RESULT}" -ne 0 ]] &&
                            fatal "Unable to pull ${IMAGE_FORMAT,,} image for deployment unit ${CURRENT_DEPLOYMENT_UNIT} and commit ${CODE_COMMIT} from provider ${FROM_IMAGE_PROVIDER}. Was the build successful?" && exit
                    else
                        fatal "${IMAGE_FORMAT^} image for deployment unit ${CURRENT_DEPLOYMENT_UNIT} and commit ${CODE_COMMIT} not found. Was the build successful?" && exit
                    fi
                fi
            done

            # Save details of this deployment unit
            CODE_COMMIT_ARRAY[${INDEX}]="${CODE_COMMIT}"
            ;;

    esac
done

# Capture any changes to context
case ${REFERENCE_OPERATION} in
    ${REFERENCE_OPERATION_LIST})
        save_context_property DETAIL_MESSAGE
        ;;

    ${REFERENCE_OPERATION_LISTFULL})
        save_context_property DEPLOYMENT_UNIT_LIST "${DEPLOYMENT_UNIT_ARRAY[*]}"
        save_context_property CODE_COMMIT_LIST "${CODE_COMMIT_ARRAY[*]}"
        save_context_property CODE_TAG_LIST "${CODE_TAG_ARRAY[*]}"
        save_context_property IMAGE_FORMATS_LIST "${IMAGE_FORMATS_ARRAY[*]}"
        save_context_property DETAIL_MESSAGE "${DETAIL_MESSAGE}"
        ;;

    ${REFERENCE_OPERATION_VERIFY})
        save_context_property CODE_COMMIT_LIST "${CODE_COMMIT_ARRAY[*]}"
        ;;

esac

# All good
RESULT=0