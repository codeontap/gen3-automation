#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit $?' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Defaults
LEVELS_DEFAULT="application"

function usage() {
    cat <<EOF

Manage one or more deployment units in one or more levels

Usage: $(basename $0) -s DEPLOYMENT_UNIT_LIST -l LEVEL_LIST -m DEPLOYMENT_MODE

where

(o) -a APPLICATION_UNITS_LIST is the list of application level units to process
(o) -c ACCOUNT_UNITS_LIST     is the list of account level units to process
(o) -g SEGMENT_UNITS_LIST     is the list of segment level units to process
    -h                        shows this text
(m) -l LEVELS                 is the list of levels to consider
(m) -m DEPLOYMENT_MODE        is the deployment mode
(o) -p PRODUCT_UNITS_LIST     is the list of product level units to process
(o) -s SOLUTION_UNITS_LIST    is the list of solution level units to process
(o) -t INFRASTRUCTURE_TAG     is the tag to use when saving the result
(o) -u MULTIPLE_UNITS_LIST    is the list of multi-level units to process

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

DEPLOYMENT_MODE = "${DEPLOYMENT_MODE_DEFAULT}"
LEVELS = "${LEVELS_DEFAULT}"

NOTES:

EOF
}

function options() {
    # Parse options
    while getopts ":a:c:g:hl:m:p:s:u:" option; do
        case $option in
            a) APPLICATION_UNITS_LIST="${OPTARG}" ;;
            c) ACCOUNT_UNITS_LIST="${OPTARG}" ;;
            g) SEGMENT_UNITS_LIST="${OPTARG}" ;;
            h) usage; return 1 ;;
            l) LEVELS_LIST="${OPTARG}" ;;
            m) DEPLOYMENT_MODE="${OPTARG}" ;;
            p) PRODUCT_UNIT_LIST="${OPTARG}" ;;
            s) SOLUTION_UNIT_LIST="${OPTARG}" ;;
            t) INFRASTRUCTURE_TAG="${OPTARG}" ;;
            u) MULTIPLE_UNIT_LIST="${OPTARG}" ;;
            \?) fatalOption; return 1 ;;
            :) fatalOptionArgument; return 1 ;;
         esac
    done
    
    # Apply defaults
    export DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-${DEPLOYMENT_MODE_DEFAULT}}"
    export LEVELS_LIST="${LEVELS_LIST:-${LEVEL_DEFAULT}}"
    export INFRASTRUCTURE_TAG="${INFRASTRUCTURE_TAG:-env${AUTOMATION_JOB_IDENTIFIER}-${SEGMENT}}"
    
    # Ensure mandatory arguments have been provided
    [[ (-z "${DEPLOYMENT_MODE}") || (-z "${LEVEL}") ]] && 
        fatalMandatory && return 1
    
    return 0
}

function main() {

  options "$@" || return $?

  # Remember if anything was processed
  save_required="false"
  
  # Process each template level
  arrayfromList levels_required "${LEVELS_LIST}"
  
  # Reverse the order if we are deleting
  [[ "${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOP}" ]] && reverseArray levels_required
  
  for level in "${levels_required[@]}"; do

    # Switch to the correct directory
    case level in 
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
    
    # Manage the units individually in case of failure and because one can depend on the 
    # output of the previous one
    for unit in "${units[@]}"; do
    
      # Say what we are doing
      info "Processing \"${level}\" level, \"${unit}\" unit ...\n"
      
      # Generate the template if required
      if [[ ("${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_UPDATE}") ]]; then
        ${GENERATION_DIR}/createTemplate.sh -u "${unit}" -l "${level}" -c "${INFRASTRUCTURE_TAG}" || return $?
      fi
      
      ${AUTOMATION_DIR}/manageStacks.sh -u "${unit}" -l "${level}" || return $?

      if [[ "${DEPLOYMENT_MODE}" != "${DEPLOYMENT_MODE_UPDATE}" ]]; then
          ${GENERATION_DIR}/manageStack.sh -u ${unit} -d ||
              { exit_status=$?; fatal "Deletion of the ${level} level stack for the ${unit} deployment unit failed"; return "${exit_status}"; }
      fi
      if [[ "${DEPLOYMENT_MODE}" != "${DEPLOYMENT_MODE_STOP}"   ]]; then
          ${GENERATION_DIR}/manageStack.sh -u ${unit} ||
              { exit_status=$?; fatal "Create/update of the ${level} level stack for the ${unit} deployment unit failed"; return "${exit_status}"; }
      fi
      save_required="true"
    done
  done
  
  # All good - save the result
  if [[ "${save_required}" == "true" ]]; then
    info "Saving changes under tag \"${INFRASTRUCTURE_TAG}\" ..."
    
    save_product_infrastructure \
    "${DETAIL_MESSAGE}, level=segment, units=cmk" \
    "${PRODUCT_INFRASTRUCTURE_REFERENCE}" \
    "${INFRASTRUCTURE_TAG}"
    RESULT=$?
  fi

  return 0
}

main "$@"

