#!/bin/bash

# Automation framework common definitions
#
# This script is designed to be sourced into other scripts

. "${AUTOMATION_BASE_DIR}/utility.sh"
. "${AUTOMATION_BASE_DIR}/contextTree.sh"

# -- Repositories --

function save_repo() {
  local directory="$1"; shift
  local name="$1"; shift
  local message="$1"; shift
  local reference="$1"; shift
  local tag="$1"; shift

  local optional_arguments=()
  [[ -n "${reference}" ]] && optional_arguments+=("-b" "${reference}")
  [[ -n "${tag}" ]] && optional_arguments+=("-t" "${tag}")

  ${AUTOMATION_DIR}/manageRepo.sh -p \
    -d "${directory}" \
    -l "${name}" \
    -m "${message}" \
    "${optional_arguments[@]}"
}

function save_product_config() {
  local arguments=("$@")

  save_repo "${PRODUCT_DIR}" config "${arguments[@]}"
}

function save_product_infrastructure() {
  local arguments=("$@")

  save_repo "${PRODUCT_INFRASTRUCTURE_DIR}" infrastructure "${arguments[@]}"
}

# -- Context properties file --

function save_context_property() {
  local name="$1"; shift
  local value="$1"; shift
  local file="${1:-${AUTOMATION_DATA_DIR}/context.properties}"; shift
  
  if [[ -n "${value}" ]]; then
    local property_value="${value}"
  else
    if namedef_supported; then
      local -n property_value="${value}"
    else
      eval "local property_value=\"\${${name}}\""
    fi
  fi

  echo "${name}=${property_value}" >> "${file}"
}

function save_chain_property() {
  local name="$1"; shift
  local value="$1"; shift

  save_context_property "${name}" "${value}" "${AUTOMATION_DATA_DIR}/chain.properties"
}

function define_context_property() {
  local name="${1^^}"; shift
  local value="$1"; shift
  local capitalisation="$1,,"; shift

  case "${capitalisation}" in
    lower)
      value="${value,,}"
      ;;
    upper)
      value="${value^^}"
      ;;
  esac
  
  declare -g ${name}="${value}"
  save_context_property "${name}" "${value}"
}

function save_gen3_dirs_in_context() {
  local prefix="$1"; shift

  local directories=(ROOT_DIR TENANT_DIR \
    ACCOUNT_DIR ACCOUNT_INFRASTRUCTURE_DIR ACCOUNT_APPSETTINGS_DIR ACCOUNT_CREDENTIALS_DIR \
    PRODUCT_DIR PRODUCT_INFRASTRUCTURE_DIR PRODUCT_APPSETTINGS_DIR PRODUCT_SOLUTIONS_DIR PRODUCT_CREDENTIALS_DIR \
    SEGMENT_DIR SEGMENT_APPSETTINGS_DIR SEGMENT_CREDENTIALS_DIR)

  for directory in "${directories[@]}"; do 
    save_context_property "${directory}" "$(getGen3Env "${directory}" "${prefix}")"
  done

  return 0
}

# -- Logging --
function getLogLevel() {
  echo -n "${AUTOMATION_LOG_LEVEL}"
}
