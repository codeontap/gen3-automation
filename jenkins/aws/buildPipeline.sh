#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

tmpdir="$(getTempDir "cota_inf_XXX")"

function main() {
    # Make sure we are in the build source directory
    cd ${AUTOMATION_BUILD_SRC_DIR}
    
    # Add extra Source Code 
    if [[ -n "${PIPELINE_EXTRA_SRC_CODE_DIR}" && -n "${PIPELINE_EXTRA_SRC_CODE_PATH}" ]]; then 
        mkdir -p "${AUTOMATION_BUILD_SRC_DIR}/${PIPELINE_EXTRA_SRC_CODE_DIR}"
        cp -r "${AUTOMATION_DATA_DIR}/${PIPELINE_EXTRA_SRC_CODE_PATH}"/* "${AUTOMATION_BUILD_SRC_DIR}/${PIPELINE_EXTRA_SRC_CODE_DIR}/"
    fi

    # Make sure we have a script to start from
    [[ ! -f pipeline-definition.json && ! -f pipeline-parameters.json ]] &&
        { fatal "No pipeline-definition.json found"; return 1; }

    zip -r "${tmpdir}/pipeline.zip" *  

    if [[ -f ${tmpdir}/pipeline.zip ]]; then
        mkdir "${AUTOMATION_BUILD_SRC_DIR}/dist"
        cp ${tmpdir}/pipeline.zip "${AUTOMATION_BUILD_SRC_DIR}/dist/pipeline.zip"
    fi

    # All good
    return 0
}

main "$@"