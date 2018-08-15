#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

tmpdir="$(getTempDir "cota_inf_XXX")"

function main() {
    # Make sure we are in the build source directory
    cd ${AUTOMATION_BUILD_SRC_DIR}
    
    # Make sure we have a script to start from
    [[ ! -f pipeline-definition.json   ]] &&
        { fatal "No pipeline-definition.json found"; return 1; }

    cp pipeline-definition.json "${tmpdir}/pipeline-definition.json"
    
    if [[ -f pipeline-parameters.json ]]; then
        cp pipeline-parameters.json "${tmpdir}/pipeline-parameters.json"
    else
        echo "{}" > "${tmpdir}/pipeline-definition.json"
    fi

    mkdir "${tmpdir}/_scripts"

    for item in *; do
        if [ -d ${item} ]; then
            cd {$item}
            zip -r "${tmpdir}/_scripts/${item}.zip" *
            cd ${AUTOMATION_BUILD_SRC_DIR}
        fi
    done

    cd "${tmpdir}"
    zip -r "${tmpdir}/pipeline.zip" *  

    if [[ -f ${tmpdir}/pipeline.zip ]]; then
        mkdir "${AUTOMATION_BUILD_SRC_DIR}/dist"
        cp ${tmpdir}/pipeline.zip "${AUTOMATION_BUILD_SRC_DIR}/dist/pipeline.zip"
    fi

    # All good
    return 0
}

main "$@"