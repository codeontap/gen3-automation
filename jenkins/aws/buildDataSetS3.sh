#!/usr/bin/env bash
[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Ge the generation context to create a bu
. "${GENERATION_DIR}/setContext.sh"

tmpdir="$(getTempDir "cota_inf_XXX")"

data_manifest_filename="cot_data_file_manifest.json"
        
function main() {
    for DEPLOYMENT_UNIT in ${DEPLOYMENT_UNITS[0]}; do

        # Generate a build blueprint so that we can find out the source S3 bucket
        . "${GENERATION_DIR}/createBuildBluePrint.sh" -u "${DEPLOYMENT_UNIT}" 
        BUILD_BLUEPRINT="${AUTOMATION_DATA_DIR}/build_blueprint-${DEPLOYMENT_UNIT}-.json"

        if [[ -f "${BUILD_BLUEPRINT}" ]]; then 

            mkdir -p "${tmpdir}/${DEPLOYMENT_UNIT}"
            data_manifest_file="${tmpdir}/${DEPLOYMENT_UNIT}/${data_manifest_filename}"

            dataset_master_location="$( jq -r '.Occurrence.State.Attributes.DATASET_MASTER_LOCATION' < "${BUILD_BLUEPRINT}" )"
            dataset_prefix="$( jq -r '.Occurrence.State.Attributes.DATASET_PREFIX' < "${BUILD_BLUEPRINT}" )"
            master_data_bucket_name="$( jq -r '.Occurrence.State.Attributes.DATASOURCE_NAME' < "${BUILD_BLUEPRINT}" )"

            info "Master Data: ${dataset_master_location} -Prefix: ${dataset_prefix} -MasterBucket: ${master_data_bucket_name}"

            aws --region "${REGISTRY_PROVIDER_REGION}" s3 list-objects-v2 --bucket "${master_data_bucket_name}" --prefix "${dataset_prefix}" --query 'Contents[*].{Key,ETag,LastModified}' > "${data_manifest_file}" 
            if [[ -f "${data_manifest_file}" ]]; then 

                build_reference="$( sha256sum "${data_manifest_file}" )"
                save_chain_property CODE_COMMIT "${build_reference}"
                save_chain_property S3_DATA_STAGE "${dataset_master_location}"

                cp "${data_manifest_file}" "${AUTOMATION_BUILD_SRC_DIR}/${data_manifest_filename}"
            
            else 
                fatal "Could not generate data manifest file"
                return 128
            fi 
                
        else 

            fatal "Could not find build blueprint"
            return 255
        fi
    done

    return 0
}

main "$@"