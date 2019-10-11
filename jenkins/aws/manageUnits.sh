#!/usr/bin/env bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit 1' SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

#Defaults 
DEFAULT_GENERATION_DOCS_BLUEPRINT="false"

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
(m) -l LEVELS_LIST            is the list of levels to process
(o) -m DEPLOYMENT_MODE        is the deployment mode if stacks are to be managed
(o) -n ACCOUNT_LIST           is the list of accounts to process
(o) -p PRODUCT_UNITS_LIST     is the list of product level units to process
(o) -r REFERENCE              reference to use when preparing templates
(o) -s SOLUTION_UNITS_LIST    is the list of solution level units to process
(o) -u MULTIPLE_UNITS_LIST    is the list of multi-level units to process
(o) -b GENERATION_DOCS_BLUEPRINT  create a build print for documentation

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

ACCOUNT_LIST=\${ACCOUNT}
GENERATION_DOCS_BLUEPRINT=${DEFAULT_GENERATION_DOCS_BLUEPRINT

NOTES:

1. Presence of -r triggers generation of templates
2. Presence of -m triggers management of stacks

EOF
}

function options() {
    # Parse options
    while getopts ":a:bc:g:hl:m:n:p:r:s:u:" option; do
        case $option in
            a) APPLICATION_UNITS_LIST="${OPTARG}" ;;
            b) GENERATION_DOCS_BLUEPRINT="true" ;;
            c) ACCOUNT_UNITS_LIST="${OPTARG}" ;;
            g) SEGMENT_UNITS_LIST="${OPTARG}" ;;
            h) usage; return 1 ;;
            l) LEVELS_LIST="${OPTARG}" ;;
            m) DEPLOYMENT_MODE="${OPTARG}" ;;
            n) ACCOUNTS_LIST="${OPTARG}" ;;
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

  GENERATION_DOCS_BLUEPRINT="${GENERATION_DOCS_BLUEPRINT:-${DEFAULT_GENERATION_DOCS_BLUEPRINT}}"

  # Process each account
  arrayFromList accounts_required "${ACCOUNTS_LIST:-${ACCOUNT}}"
  arrayIsEmpty  accounts_required && warning "No account(s) to process\n"

  # Process each template level
  arrayFromList levels_required "${LEVELS_LIST}"
  arrayIsEmpty  levels_required && warning "No level(s) to process\n"

  # Reverse the order if we are deleting
  [[ "${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOP}" ]] && reverseArray levels_required

  for account in "${accounts_required[@]}"; do

    info "Processing account ${account} ...\n"

    # setContext will have set up for the first account in the list
    if [[ "${account}" != "${ACCOUNT}" ]]; then
      export ACCOUNT="${account}"

      info "Getting credentials for account ${account} ...\n"

      . ${AUTOMATION_DIR}/setCredentials.sh "${ACCOUNT}"
      export ACCOUNT_AWS_ACCESS_KEY_ID_VAR="${AWS_CRED_AWS_ACCESS_KEY_ID_VAR}"
      export ACCOUNT_AWS_SECRET_ACCESS_KEY_VAR="${AWS_CRED_AWS_SECRET_ACCESS_KEY_VAR}"
      export ACCOUNT_TEMP_AWS_ACCESS_KEY_ID="${AWS_CRED_TEMP_AWS_ACCESS_KEY_ID}"
      export ACCOUNT_TEMP_AWS_SECRET_ACCESS_KEY="${AWS_CRED_TEMP_AWS_SECRET_ACCESS_KEY}"
      export ACCOUNT_TEMP_AWS_SESSION_TOKEN="${AWS_CRED_TEMP_AWS_SESSION_TOKEN}"
    fi

    for level in "${levels_required[@]}"; do

      # Switch to the correct directory
      case "${level}" in
        account)     cd "${ACCOUNT_DIR}"; units_list="${ACCOUNT_UNITS_LIST}" ;;
        product)     cd "${PRODUCT_DIR}"; units_list="${PRODUCT_UNITS_LIST}" ;;
        application) cd "${SEGMENT_SOLUTIONS_DIR}"; units_list="${APPLICATION_UNITS_LIST}" ;;
        solution)    cd "${SEGMENT_SOLUTIONS_DIR}"; units_list="${SOLUTION_UNITS_LIST}" ;;
        segment)     cd "${SEGMENT_SOLUTIONS_DIR}"; units_list="${SEGMENT_UNITS_LIST}" ;;
        multiple)    cd "${SEGMENT_SOLUTIONS_DIR}"; units_list="${MULTIPLE_UNITS_LIST}" ;;
        *) fatal "Unknown level ${level}"; return 1 ;;
      esac

      arrayFromList units_required "${units_list}" "${DEPLOYMENT_UNIT_SEPARATORS}"
      arrayIsEmpty  units_required && warning "No unit(s) to process"

      # Reverse the order if we are deleting
      [[ "${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOP}" ]] && reverseArray units_required

      # Manage the units individually as one can depend on the output of previous ones
      for unit_build_reference in "${units_required[@]}"; do

        # Extract the deployment unit
        arrayFromList "build_reference_parts" "${unit_build_reference}" "${BUILD_REFERENCE_PART_SEPARATORS}"
        unit="${build_reference_parts[0]}"

        # Say what we are doing
        info "Processing \"${level}\" level, \"${unit}\" unit ...\n"

        # Generate the template if required
        if [[ -n "${REFERENCE}" ]]; then
          ${GENERATION_DIR}/createTemplate.sh -l "${level}" -u "${unit}" -c "${REFERENCE}" || return $?
        fi

        # Manage the stack if required
        if [[ -n "${DEPLOYMENT_MODE}" ]]; then
          if [[ "${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOP}" || "${DEPLOYMENT_MODE}" == "${DEPLOYMENT_MODE_STOPSTART}" ]]; then
              ${GENERATION_DIR}/manageStack.sh -d -l "${level}" -u "${unit}" ||
                  { exit_status=$?; fatal "Deletion of the ${level} level stack for the ${unit} deployment unit failed"; return "${exit_status}"; }
          fi
          if [[ "${DEPLOYMENT_MODE}" != "${DEPLOYMENT_MODE_STOP}"   ]]; then
              ${GENERATION_DIR}/manageStack.sh -l "${level}" -u "${unit}" ||
                  { exit_status=$?; fatal "Create/update of the ${level} level stack for the ${unit} deployment unit failed"; return "${exit_status}"; }
          fi
        fi
      done
      
      # Update blueprint if a stack is being managed
      # - Currently the blueprint only generates a segment level blueprin
      if [[ "${level}" != "account" && "${level}" != "product" && "${GENERATION_DOCS_BLUEPRINT}" == "true" ]]; then
          info "Generating deployment blueprint... \n"
          ${GENERATION_DIR}/createTemplate.sh -l blueprint 2>/dev/null || 
              { warning "An issue occurred generating the blueprint - This will not break things but could be an issue with your components"; }
      fi
    done
  done

  return 0
}

main "$@"

