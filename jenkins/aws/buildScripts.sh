#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap '[[ (-z "${AUTOMATION_DEBUG}") ; exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

tmpdir="$(getTempDir "cota_inf_XXX")"

function main() {
    # Make sure we are in the build source directory
    cd ${AUTOMATION_BUILD_SRC_DIR}
    
    # Mkae sure we have a script to start from
    [[ ! -f init.sh ]] &&
        { fatal "No init.sh found - this is the entry point for this build type"; return 1; }

    zip -r "${tmpdir}/scripts.zip" * 

    if [[ -f ${tmpdir}/scripts.zip ]]; then
        mkdir "${AUTOMATION_BUILD_SRC_DIR}/dist"
        cp ${tmpdir}/scripts.zip "${AUTOMATION_BUILD_SRC_DIR}/dist/scripts.zip"
    fi

    # All good
    return 0
}

main "$@"