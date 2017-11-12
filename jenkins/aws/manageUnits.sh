#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function usage() {
    cat <<EOF

Manage one or more deployment units in one or more levels

Usage: $(basename $0) -l LEVELS_LIST -r REFERENCE -m DEPLOYMENT_MODE
                      -c ACCOUNT_UNITS_LIST
                      -p PRODUCT_UNITS_LIST
                      -a APPLICATION_UNITS_LIST
                      -s SOLUTION_UNITS_LIST
                      -f SEGMENT_UNITS_LIST
                      -u MULTIPLE_UNITS_LIST
                      -t UNITS_TAG

where

(o) -a APPLICATION_UNITS_LIST is the list of application level units to process
(o) -c ACCOUNT_UNITS_LIST     is the list of account level units to process
(o) -g SEGMENT_UNITS_LIST     is the list of segment level units to process
    -h                        shows this text
(m) -l LEVELS_LIST            is the list of levels to consider
(o) -m DEPLOYMENT_MODE        is the deployment mode if stacks are to be managed
(o) -p PRODUCT_UNITS_LIST     is the list of product level units to process
(o) -r REFERENCE              reference to use when preparing templates
(o) -s SOLUTION_UNITS_LIST    is the list of solution level units to process
(o) -u MULTIPLE_UNITS_LIST    is the list of multi-level units to process

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

NOTES:

1. Presence of -r triggers generation of templates
2. Presence of -m triggers management of stacks

EOF
}

function options() {
    # Parse options
    while getopts ":a:c:g:hl:m:p:r:s:u:" option; do
        case $option in
            a) APPLICATION_UNITS_LIST="${OPTARG}" ;;
            c) ACCOUNT_UNITS_LIST="${OPTARG}" ;;
            g) SEGMENT_UNITS_LIST="${OPTARG}" ;;
            h) usage; return 1 ;;
            l) LEVELS_LIST="${OPTARG}" ;;
            m) DEPLOYMENT_MODE="${OPTARG}" ;;
            p) PRODUCT_UNITS_LIST="${OPTARG}" ;;
            r) REFERENCE="${OPTARG}" ;;
            s) SOLUTION_UNITS_LIST="${OPTARG}" ;;
            u) MULTIPLE_UNITS_LIST="${OPTARG}" ;;
            \?) fatalOption; return 1 ;;
            :) fatalOptionArgument; return 1 ;;
         esac
    done

    return 0
}

function main() {

  options "$@" || return $?

  # Process each template level
  arrayFromList levels_required "${LEVELS_LIST}"
  
  # Reverse the order if we are deleting
  [[ "${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOP}" ]] && reverseArray levels_required
  
  for level in "${levels_required[@]}"; do

    # Switch to the correct directory
    case "${level}" in
      account)     cd "${ACCOUNT_DIR}"; units_list="${ACCOUNT_UNITS_LIST}" ;;
      product)     cd "${PRODUCT_DIR}"; units_list="${PRODUCT_UNITS_LIST}" ;;
      application) cd "${SEGMENT_DIR}"; units_list="${APPLICATION_UNITS_LIST}" ;;
      solution)    cd "${SEGMENT_DIR}"; units_list="${SOLUTION_UNITS_LIST}" ;;
      segment)     cd "${SEGMENT_DIR}"; units_list="${SEGMENT_UNITS_LIST}" ;;
      multiple)    cd "${SEGMENT_DIR}"; units_list="${MULTIPLE_UNITS_LIST}" ;;
      *) fatal "Unknown level ${level}"; return 1 ;;
    esac

    arrayFromList "units" "${units_list}" "${DEPLOYMENT_UNIT_SEPARATORS}"
    
    # Reverse the order if we are deleting
    [[ "${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOP}" ]] && reverseArray units
    
    # Manage the units individually as one can depend on the output of previous ones
    for unit in "${units[@]}"; do
    
      # Say what we are doing
      info "Processing \"${level}\" level, \"${unit}\" unit ...\n"
      
      # Generate the template if required
      if [[ -n "${REFERENCE}" ]]; then
        ${GENERATION_DIR}/createTemplate.sh -u "${unit}" -l "${level}" -c "${REFERENCE}" || return $?
      fi

      # Manage the stack if required
      if [[ -n "${DEPLOYMENT_MODE}" ]]; then
        if [[ "${DEPLOYMENT_MODE}" != "${DEPLOYMENT_MODE_UPDATE}" ]]; then
            ${GENERATION_DIR}/manageStack.sh -u ${unit} -d ||
                { exit_status=$?; fatal "Deletion of the ${level} level stack for the ${unit} deployment unit failed"; return "${exit_status}"; }
        fi
        if [[ "${DEPLOYMENT_MODE}" != "${DEPLOYMENT_MODE_STOP}"   ]]; then
            ${GENERATION_DIR}/manageStack.sh -u ${unit} ||
                { exit_status=$?; fatal "Create/update of the ${level} level stack for the ${unit} deployment unit failed"; return "${exit_status}"; }
        fi
      fi
    done
  done
  
  return 0
}

main "$@"

