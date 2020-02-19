#!/usr/bin/env bash

# AUTOMATION_BASE_DIR assumed to be pointing to base of gen3-automation tree

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

function usage() {
  cat <<EOF

Determine key settings for an tenant/account/product/segment

Usage: $(basename $0) -i INTEGRATOR -t TENANT -a ACCOUNT -p PRODUCT -e ENVIRONMENT -s SEGMENT -r RELEASE_MODE -d DEPLOYMENT_MODE

where

(o) -a ACCOUNT          is the tenant account name e.g. "nonproduction"
(o) -d DEPLOYMENT_MODE  is the mode to be used for deployment activity
(o) -e ENVIRONMENT      is the environment name e.g. "production"
    -h                  shows this text
(o) -i INTEGRATOR       is the integrator name
(o) -p PRODUCT          is the product name e.g. "eticket"
(o) -r RELEASE_MODE     is the mode to be used for release activity
(o) -s SEGMENT          is the SEGMENT name e.g. "default"
(o) -t TENANT           is the tenant name e.g. "env"

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

RELEASE_MODE = ${RELEASE_MODE_DEFAULT}
DEPLOYMENT_MODE = ${DEPLOYMENT_MODE_DEFAULT}
ACCOUNT=\${ACCOUNT_LIST[0]}

NOTES:

1. The setting values are saved in context.properties in the current directory
2. DEPLOYMENT_MODE is one of "${DEPLOYMENT_MODE_UPDATE}", "${DEPLOYMENT_MODE_STOPSTART}" and "${DEPLOYMENT_MODE_STOP} or custom update deployment modes"
3. RELEASE_MODE is one of "${RELEASE_MODE_CONTINUOUS}", "${RELEASE_MODE_SELECTIVE}", "${RELEASE_MODE_ACCEPTANCE}", "${RELEASE_MODE_PROMOTION}" and "${RELEASE_MODE_HOTFIX}"

EOF
  exit
}

function findAndDefineSetting() {
    # Find the value for a name
    TLNV_NAME="${1^^}"
    TLNV_SUFFIX="${2^^}"
    TLNV_LEVEL1="${3^^}"
    TLNV_LEVEL2="${4^^}"
    TLNV_DECLARE="${5,,}"
    TLNV_DEFAULT="${6}"

    # Variables to check
    declare NAME_VAR="${TLNV_NAME}"
    declare NAME_LEVEL2_VAR="${TLNV_LEVEL1}_${TLNV_LEVEL2}_${TLNV_SUFFIX}"
    declare NAME_LEVEL1_VAR="${TLNV_LEVEL1}_${TLNV_SUFFIX}"

    # Already defined?
    if [[ (-z "${NAME_VAR}") || (-z "${!NAME_VAR}") ]]; then

        # Two level definition?
        if [[ (-n "${TLNV_LEVEL2}") && (-n "${!NAME_LEVEL2_VAR}") ]]; then
            NAME_VAR="${NAME_LEVEL2_VAR}"
        else
            # One level definition?
            if [[ (-n "${TLNV_LEVEL1}") && (-n "${!NAME_LEVEL1_VAR}") ]]; then
                NAME_VAR="${NAME_LEVEL1_VAR}"
            fi
        fi
    fi

    if [[ -n "${!NAME_VAR}" ]]; then
        # Value found
        NAME_VALUE="${!NAME_VAR}"
    else
        # Use the default
        NAME_VAR=""
        NAME_VALUE="${TLNV_DEFAULT}"
    fi

    case "${TLNV_DECLARE}" in
        value)
            define_context_property "${TLNV_NAME}" "${NAME_VALUE}" "lower"
            ;;

        name)
            define_context_property "${TLNV_NAME}" "${NAME_VAR}" "upper"
            ;;
    esac
}

GIT_PROVIDERS=()
function defineGitProviderSettings() {
    # Define key values about use of a git provider
    DGPD_USE="${1}"
    DGPD_SUBUSE="${2}"
    DGPD_LEVEL1="${3}"
    DGPD_LEVEL2="${4}"
    DGPD_DEFAULT="${5}"
    DGPD_SUBUSE_PREFIX="${6}"
    DGPD_SUBUSE_PREFIX_PROVIDED="${6+x}"

    # Provider type
    DGPD_PROVIDER_TYPE="GIT"

    # Format subuse
    if [[ -n "${DGPD_SUBUSE}" ]]; then
        DGPD_SUBUSE="${DGPD_SUBUSE}_"
    fi

    # Default subuse prefix if not explicitly provided
    if [[ -z "${DGPD_SUBUSE_PREFIX_PROVIDED}" ]]; then
        DGPD_SUBUSE_PREFIX="${DGPD_SUBUSE}"
    fi

    # Format subuse prefix
    if [[ -n "${DGPD_SUBUSE_PREFIX}" ]]; then
        DGPD_SUBUSE_PREFIX="${DGPD_SUBUSE_PREFIX}_"
    fi

    # Find the provider
    findAndDefineSetting "${DGPD_USE}_${DGPD_SUBUSE}${DGPD_PROVIDER_TYPE}_PROVIDER" \
        "${DGPD_SUBUSE_PREFIX}${DGPD_PROVIDER_TYPE}_PROVIDER" \
        "${DGPD_LEVEL1}" "${DGPD_LEVEL2}" "value" "${DGPD_DEFAULT}"
    DGPD_PROVIDER="${NAME_VALUE,,}"

    # Already seen?
    for PROVIDER in ${GIT_PROVIDERS[@]}; do
        if [[ "${PROVIDER}" == "${DGPD_PROVIDER}" ]]; then
            return
        fi
    done

    # Seen now
    GIT_PROVIDERS+=("${DGPD_PROVIDER}")

    # Ensure all attributes defined

    # Dereferenced provider attributes
    for ATTRIBUTE in CREDENTIALS; do
        findAndDefineSetting  "${DGPD_PROVIDER}_${DGPD_PROVIDER_TYPE}_${ATTRIBUTE}_VAR" \
            "${ATTRIBUTE}" "${DGPD_PROVIDER}" "${DGPD_PROVIDER_TYPE}" "name"
    done

    # Provider attributes
    for ATTRIBUTE in ORG DNS; do
        findAndDefineSetting "${DGPD_PROVIDER}_${DGPD_PROVIDER_TYPE}_${ATTRIBUTE}" \
            "${ATTRIBUTE}" "${DGPD_PROVIDER}" "${DGPD_PROVIDER_TYPE}" "value"
    done

    # API_DNS defaults to DNS
    # NOTE: NAME_VALUE use assumes DNS was last setting defined
    findAndDefineSetting "${DGPD_PROVIDER}_${DGPD_PROVIDER_TYPE}_API_DNS" \
        "API_DNS" "${DGPD_PROVIDER}" "${DGPD_PROVIDER_TYPE}" "value" "api.${NAME_VALUE}"
}

REGISTRY_TYPES=("dataset" "docker" "lambda" "pipeline" "scripts" "swagger" "openapi" "spa" "contentnode" "rdssnapshot" )
REGISTRY_PROVIDERS=()
function defineRegistryProviderSettings() {
    # Define key values about use of a docker provider
    DRPS_PROVIDER_TYPE="${1^^}"
    DRPS_USE="$2"
    DRPS_SUBUSE="$3"
    DRPS_LEVEL1="$4"
    DRPS_LEVEL2="$5"
    DRPS_DEFAULT="$6"
    DRPS_SUBUSE_PREFIX="$7"
    DRPS_SUBUSE_PREFIX_PROVIDED="${7+x}"

    # Format subuse
    if [[ -n "${DRPS_SUBUSE}" ]]; then
        DRPS_SUBUSE="${DRPS_SUBUSE}_"
    fi

    # Default subuse prefix if not explicitly provided
    if [[ -z "${DRPS_SUBUSE_PREFIX_PROVIDED}" ]]; then
        DRPS_SUBUSE_PREFIX="${DRPS_SUBUSE}"
    fi

    # Format subuse prefix
    if [[ -n "${DRPS_SUBUSE_PREFIX}" ]]; then
        DRPS_SUBUSE_PREFIX="${DRPS_SUBUSE_PREFIX}_"
    fi

    # Find the provider
    findAndDefineSetting "${DRPS_USE}_${DRPS_SUBUSE}${DRPS_PROVIDER_TYPE}_PROVIDER" \
        "${DRPS_SUBUSE_PREFIX}${DRPS_PROVIDER_TYPE}_PROVIDER" \
        "${DRPS_LEVEL1}" "${DRPS_LEVEL2}" "value" "${DRPS_DEFAULT}"
    DRPS_PROVIDER="${NAME_VALUE,,}"

    # Already seen?
    for PROVIDER in ${DOCKER_PROVIDERS[@]}; do
        if [[ "${PROVIDER}" == "${DRPS_PROVIDER_TYPE},${DRPS_PROVIDER}" ]]; then
            return
        fi
    done

    # Seen now
    DOCKER_PROVIDERS+=("${DRPS_PROVIDER_TYPE},${DRPS_PROVIDER}")

    # Ensure all attributes defined

    # Dereferenced provider attributes
    for ATTRIBUTE in USER PASSWORD; do
        findAndDefineSetting "${DRPS_PROVIDER}_${DRPS_PROVIDER_TYPE}_${ATTRIBUTE}_VAR" \
            "${ATTRIBUTE}" "${DRPS_PROVIDER}" "${DRPS_PROVIDER_TYPE}" "name"
    done

    # Provider attributes
    for ATTRIBUTE in REGION DNS; do
        findAndDefineSetting "${DRPS_PROVIDER}_${DRPS_PROVIDER_TYPE}_${ATTRIBUTE}" \
        "${ATTRIBUTE}" "${DRPS_PROVIDER}" "${DRPS_PROVIDER_TYPE}" "value"
    done

    # API_DNS defaults to DNS
    # NOTE: NAME_VALUE use assumes DNS was last setting defined
    findAndDefineSetting "${DRPS_PROVIDER}_${DRPS_PROVIDER_TYPE}_API_DNS" \
        "API_DNS" "${DRPS_PROVIDER}" "${DRPS_PROVIDER_TYPE}" "value" "${NAME_VALUE}"
}

function defineRepoSettings() {
    # Define key values about use of a code repo
    DRD_USE="$1"
    DRD_SUBUSE="$2"
    DRD_LEVEL1="$3"
    DRD_LEVEL2="$4"
    DRD_DEFAULT="$5"
    DRD_TYPE="$6"

    # Optional repo type
    DRD_TYPE_PREFIX=""
    if [[ -n "${DRD_TYPE}" ]]; then
        DRD_TYPE_PREFIX="${DRD_TYPE}_"
    fi

    # Find the repo
    findAndDefineSetting "${DRD_USE}_${DRD_SUBUSE}_${DRD_TYPE_PREFIX}REPO" "${DRD_TYPE:-${DRD_SUBUSE}}_REPO" \
        "${DRD_LEVEL1}" "${DRD_LEVEL2}" "" "${DRD_DEFAULT}"

    # Strip off any path info for legacy compatability
    if [[ -n "${NAME_VALUE}" ]]; then
        NAME_VALUE="$(fileName "${NAME_VALUE}")"
    fi

    define_context_property "${DRD_USE}_${DRD_SUBUSE}_${DRD_TYPE_PREFIX}REPO" "${NAME_VALUE}"
}

function main() {

  ### Automation framework details ###

  # First things first - what automation provider are we?
  if [[ -n "${JOB_NAME}" ]]; then
    AUTOMATION_PROVIDER="${AUTOMATION_PROVIDER:-jenkins}"
  fi
  AUTOMATION_PROVIDER="${AUTOMATION_PROVIDER,,}"
  # TODO(rossmurr4y): Update to use AUTOMATION_PROVIDER once there is more than the jenkins provider dir.
  # AUTOMATION_PROVIDER_DIR="${AUTOMATION_BASE_DIR}/${AUTOMATION_PROVIDER}"
  AUTOMATION_PROVIDER_DIR="${AUTOMATION_BASE_DIR}/jenkins"


  ### Context from automation provider ###

  # TODO(rossmurr4y): seperate out azure pipelines
  case "${AUTOMATION_PROVIDER}" in
    jenkins)
      # Determine the aggregator/integrator/tenant/product/environment/segment from
      # the job name if not already defined or provided on the command line
      # Only parts of the jobname starting with "cot.?-" are
      # considered and this prefix is removed to give the actual name
      JOB_PATH=($(tr "/" " " <<< "${JOB_NAME}"))
      for PART in "${JOB_PATH[@]}"; do
        if contains "${PART}" "^(cot.?)-(.+)"; then
          case "${BASH_REMATCH[1]}" in
            cota) AGGREGATOR="${AGGREGATOR:-${BASH_REMATCH[2]}}" ;;
            coti) INTEGRATOR="${INTEGRATOR:-${BASH_REMATCH[2]}}" ;;
            cott) TENANT="${TENANT:-${BASH_REMATCH[2}}" ;;
            cotw) WORKAREA="${WORKAREA:-${BASH_REMATCH[2]}}" ;;
            cotp) PRODUCT="${PRODUCT:-${BASH_REMATCH[2]}}" ;;
            cote) ENVIRONMENT="${ENVIRONMENT:-${BASH_REMATCH[2]}}" ;;
            cots) SEGMENT="${SEGMENT:-${BASH_REMATCH[2]}}" ;;
          esac
        fi
      done

      # Use the user info for git commits
      GIT_USER="${GIT_USER:-$BUILD_USER}"
      GIT_EMAIL="${GIT_EMAIL:-$BUILD_USER_EMAIL}"

      # Working directory
      AUTOMATION_DATA_DIR="${WORKSPACE}"

      # Build directory
      AUTOMATION_BUILD_DIR="${AUTOMATION_DATA_DIR}"
      [[ -d build ]] && AUTOMATION_BUILD_DIR="${AUTOMATION_BUILD_DIR}/build"
      if [[ -n "${BUILD_PATH}" ]]; then
        [[ -d "${AUTOMATION_BUILD_DIR}/${BUILD_PATH}" ]] &&
          AUTOMATION_BUILD_DIR="${AUTOMATION_BUILD_DIR}/${BUILD_PATH}" ||
            { fatal "Build path directory \"${BUILD_PATH}\" not found"; exit; }
      fi

      # Build source directory
      AUTOMATION_BUILD_SRC_DIR="${AUTOMATION_BUILD_DIR}"

      if [[ -n "${BUILD_SRC_DIR}" ]]; then
        [[ -d "${AUTOMATION_BUILD_DIR}/${BUILD_SRC_DIR}" ]] &&
            AUTOMATION_BUILD_SRC_DIR="${AUTOMATION_BUILD_DIR}/${BUILD_SRC_DIR}" ||
            { fatal "Build source directory ${BUILD_SRC_DIR} not found"; exit; }
      else
        for sub_dir in "src" "app" "content" "pkg" "package" "content"; do
            [[ -d "${AUTOMATION_BUILD_DIR}/${sub_dir}" ]] &&
                AUTOMATION_BUILD_SRC_DIR="${AUTOMATION_BUILD_DIR}/${sub_dir}"
        done
      fi

      # Build devops directory
      AUTOMATION_BUILD_DEVOPS_DIR="${AUTOMATION_BUILD_DIR}"
      [[ -d "${AUTOMATION_BUILD_DIR}/devops" ]] &&
        AUTOMATION_BUILD_DEVOPS_DIR="${AUTOMATION_BUILD_DIR}/devops"
      [[ -d "${AUTOMATION_BUILD_DIR}/deploy" ]] &&
        AUTOMATION_BUILD_DEVOPS_DIR="${AUTOMATION_BUILD_DIR}/deploy"

      # Job identifier
      AUTOMATION_JOB_IDENTIFIER="${BUILD_NUMBER}"
      ;;
    azurepipelines)
      save_context_property GIT_USER "${GIT_USER:-$BUILD_USER}"
      save_context_property GIT_EMAIL "${GIT_EMAIL:-$BUILD_USER_EMAIL}"
      save_context_property AUTOMATION_DATA_DIR "${WORKSPACE}"

      # Build devops directory
      [[ -d "${WORKSPACE}/devops" ]] &&
        save_context_property AUTOMATION_BUILD_DIR "${WORKSPACE}/devops"
      [[ -d "${WORKSPACE}/deploy" ]] &&
        save_context_property AUTOMATION_BUILD_DIR "${WORKSPACE}/deploy"
      [[ -z "${WORKSPACE}" ]] &&
        save_context_property AUTOMATION_BUILD_DIR "${WORKSPACE}"

      save_context_property AUTOMATION_BUILD_SRC_DIR "${WORKSPACE}"
      save_context_property AUTOMATION_BUILD_DEVOPS_DIR "${WORKSPACE}"
    ;;
  esac

  # Parse options
  while getopts ":a:d:e:hi:p:r:s:t:" option; do
    case "${option}" in
      a) ACCOUNT="${OPTARG}" ;;
      d) DEPLOYMENT_MODE="${OPTARG}" ;;
      e) ENVIRONMENT="${OPTARG}" ;;
      h) usage ;;
      i) INTEGRATOR="${OPTARG}" ;;
      p) PRODUCT="${OPTARG}" ;;
      r) RELEASE_MODE="${OPTARG}" ;;
      s) SEGMENT="${OPTARG}" ;;
      t) TENANT="${OPTARG}" ;;
      \?) fatalOption ;;
      :) fatalOptionArgument ;;
     esac
  done

  ### Core settings ###

  # Release and Deployment modes

  define_context_property DEPLOYMENT_MODE_UPDATE    "update"
  define_context_property DEPLOYMENT_MODE_STOPSTART "stopstart"
  define_context_property DEPLOYMENT_MODE_STOP      "stop"
  define_context_property DEPLOYMENT_MODE_DEFAULT   "${DEPLOYMENT_MODE_UPDATE}"

  define_context_property RELEASE_MODE_CONTINUOUS   "continuous"
  define_context_property RELEASE_MODE_SELECTIVE    "selective"
  define_context_property RELEASE_MODE_ACCEPTANCE   "acceptance"
  define_context_property RELEASE_MODE_PROMOTION    "promotion"
  define_context_property RELEASE_MODE_HOTFIX       "hotfix"
  define_context_property RELEASE_MODE_DEFAULT      "${RELEASE_MODE_CONTINUOUS}"

  findAndDefineSetting "TENANT" "" "" "" "value"
  findAndDefineSetting "PRODUCT" "" "" "" "value"

  # Legacy support for case where ENVIRONMENT not set and SEGMENT is
  if [[ (-n "${SEGMENT}") && (-z "${ENVIRONMENT}") ]]; then
      ENVIRONMENT="${SEGMENT}"
      SEGMENT=""
  fi

  # Use "default" if no segment provided
  [[ -z "${SEGMENT}" ]] && SEGMENT="default"

  if [[ "${SEGMENT}" == "default" ]]; then
    DEPLOYMENT_LOCATION="${ENVIRONMENT}"
  else
    DEPLOYMENT_LOCATION="${ENVIRONMENT}-${SEGMENT}"
  fi

  findAndDefineSetting "ENVIRONMENT" "" "" "" "value" "${ENVIRONMENT}"
  findAndDefineSetting "SEGMENT"     "" "" "" "value" "${SEGMENT}"

  # Determine the account from the product/segment combination
  # if not already defined or provided on the command line
  arrayFromList accounts_list "${ACCOUNTS_LIST}"
  findAndDefineSetting "ACCOUNT" "ACCOUNT" "${PRODUCT}" "${ENVIRONMENT}" "value" "${accounts_list[0]}"

  # Default account/product git provider - "github"
  # ORG is product specific so not defaulted here
  findAndDefineSetting "GITHUB_GIT_DNS" "" "" "" "value" "github.com"

  # Default generation framework git provider - "codeontap"
  findAndDefineSetting "CODEONTAP_GIT_DNS" "" "" "" "value" "github.com"
  findAndDefineSetting "CODEONTAP_GIT_ORG" "" "" "" "value" "codeontap"

  # Default who to include as the author if git updates required
  findAndDefineSetting "GIT_USER"  "" "" "" "value" "${GIT_USER_DEFAULT:-automation}"
  findAndDefineSetting "GIT_EMAIL" "" "" "" "value" "${GIT_EMAIL_DEFAULT}"

  # Separators
  # Be careful if changing DEPLOYMENT_UNIT_SEPARATORS as jenkins inject plugin
  # won't honour space at the start or end of the separate character list
  findAndDefineSetting "DEPLOYMENT_UNIT_SEPARATORS" "" "${PRODUCT}" "${ENVIRONMENT}" "value" "; ,"
  findAndDefineSetting "BUILD_REFERENCE_PART_SEPARATORS" "" "${PRODUCT}" "${ENVIRONMENT}" "value" "!?&"
  findAndDefineSetting "IMAGE_FORMAT_SEPARATORS" "" "${PRODUCT}" "${ENVIRONMENT}" "value" ":|"

  # Modes
  findAndDefineSetting "DEPLOYMENT_MODE" "" "" "" "value" "${MODE}"
  findAndDefineSetting "RELEASE_MODE" "" "" "" "value" "${RELEASE_MODE_CONTINUOUS}"

  ### Account details ###

  # - provider
  findAndDefineSetting "ACCOUNT_PROVIDER" "ACCOUNT_PROVIDER" "${ACCOUNT}" "" "value" "aws"
  AUTOMATION_DIR="${AUTOMATION_PROVIDER_DIR}/${ACCOUNT_PROVIDER}"


  # - access credentials
  case "${ACCOUNT_PROVIDER}" in
      aws)
          . ${AUTOMATION_DIR}/setCredentials.sh "${ACCOUNT}"
          save_context_property ACCOUNT_AWS_ACCESS_KEY_ID_VAR      "${AWS_CRED_AWS_ACCESS_KEY_ID_VAR}"
          save_context_property ACCOUNT_AWS_SECRET_ACCESS_KEY_VAR  "${AWS_CRED_AWS_SECRET_ACCESS_KEY_VAR}"
          save_context_property ACCOUNT_TEMP_AWS_ACCESS_KEY_ID     "${AWS_CRED_TEMP_AWS_ACCESS_KEY_ID}"
          save_context_property ACCOUNT_TEMP_AWS_SECRET_ACCESS_KEY "${AWS_CRED_TEMP_AWS_SECRET_ACCESS_KEY}"
          save_context_property ACCOUNT_TEMP_AWS_SESSION_TOKEN     "${AWS_CRED_TEMP_AWS_SESSION_TOKEN}"
          ;;
  esac

  # - cmdb git provider
  defineGitProviderSettings "ACCOUNT" "" "${ACCOUNT}" "" "github"

  # - cmdb repos
  defineRepoSettings "ACCOUNT" "CONFIG"         "${ACCOUNT}" "" "accounts-cmdb"
  defineRepoSettings "ACCOUNT" "INFRASTRUCTURE" "${ACCOUNT}" "" "accounts-cmdb"


  ### Product details ###

  # - cmdb git provider
  defineGitProviderSettings "PRODUCT" "" "${PRODUCT}" "${ENVIRONMENT}" "${ACCOUNT_GIT_PROVIDER}"

  # - cmdb repos
  defineRepoSettings "PRODUCT" "CONFIG"         "${PRODUCT}" "${ENVIRONMENT}" "${PRODUCT}-cmdb"
  defineRepoSettings "PRODUCT" "INFRASTRUCTURE" "${PRODUCT}" "${ENVIRONMENT}" "${PRODUCT}-cmdb"

  # - code git provider
  defineGitProviderSettings "PRODUCT" "CODE" "${PRODUCT}" "${ENVIRONMENT}" "${PRODUCT_GIT_PROVIDER}"

  # - local registry providers
  for REGISTRY_TYPE in "${REGISTRY_TYPES[@]}"; do
      defineRegistryProviderSettings "${REGISTRY_TYPE}" "PRODUCT" "" "${PRODUCT}" "${ENVIRONMENT}" "${ACCOUNT}"
  done


  ### Generation framework details ###

  # - git provider
  defineGitProviderSettings "GENERATION" ""  "${PRODUCT}" "${ENVIRONMENT}" "codeontap"

  # - repos
  defineRepoSettings "GENERATION" "BIN"      "${PRODUCT}" "${ENVIRONMENT}" "gen3.git"
  defineRepoSettings "GENERATION" "PATTERNS" "${PRODUCT}" "${ENVIRONMENT}" "gen3-patterns.git"
  defineRepoSettings "GENERATION" "STARTUP"  "${PRODUCT}" "${ENVIRONMENT}" "gen3-startup.git"


  ### Application deployment unit details ###

  # Determine the deployment unit list and optional corresponding metadata
  DEPLOYMENT_UNIT_ARRAY=()
  CODE_COMMIT_ARRAY=()
  CODE_TAG_ARRAY=()
  CODE_REPO_ARRAY=()
  CODE_PROVIDER_ARRAY=()
  IMAGE_FORMATS_ARRAY=()
  arrayFromList "UNITS" "${DEPLOYMENT_UNITS:-${DEPLOYMENT_UNIT:-${SLICES:-${SLICE}}}}" "${DEPLOYMENT_UNIT_SEPARATORS}"
  for CURRENT_DEPLOYMENT_UNIT in "${UNITS[@]}"; do
      [[ -z "${CURRENT_DEPLOYMENT_UNIT}" ]] && continue
      arrayFromList "BUILD_REFERENCE_PARTS" "${CURRENT_DEPLOYMENT_UNIT}" "${BUILD_REFERENCE_PART_SEPARATORS}"
      DEPLOYMENT_UNIT_PART="${BUILD_REFERENCE_PARTS[0]}"
      TAG_PART="${BUILD_REFERENCE_PARTS[1]:-?}"
      FORMATS_PART="${BUILD_REFERENCE_PARTS[2]:-?}"
      COMMIT_PART="?"
      if [[ ("${#DEPLOYMENT_UNIT_ARRAY[@]}" -eq 0) ||
              ("${APPLY_TO_ALL_DEPLOYMENT_UNITS}" == "true") ]]; then
          # Processing the first deployment unit
          if [[ -n "${CODE_TAG}" ]]; then
              # Permit separate variable for tag/commit value - easier if only one repo involved
              TAG_PART="${CODE_TAG}"
          fi
          if [[ (-n "${IMAGE_FORMATS}") || (-n "${IMAGE_FORMAT}") ]]; then
              # Permit separate variable for formats value - easier if only one repo involved
              # Allow comma and space since its a dedicated parameter - normally they are not format separators
              IFS="${IMAGE_FORMAT_SEPARATORS}, " read -ra FORMATS <<< "${IMAGE_FORMATS:-${IMAGE_FORMAT}}"
              FORMATS_PART=$(IFS="${IMAGE_FORMAT_SEPARATORS}"; echo "${FORMATS[*]}")
          fi
      fi

      if [[ "${#TAG_PART}" -eq 40 ]]; then
          # Assume its a full commit ids - at this stage we don't accept short commit ids
          COMMIT_PART="${TAG_PART}"
          TAG_PART="?"
      fi

      DEPLOYMENT_UNIT_ARRAY+=("${DEPLOYMENT_UNIT_PART,,}")
      CODE_COMMIT_ARRAY+=("${COMMIT_PART,,}")
      CODE_TAG_ARRAY+=("${TAG_PART}")
      IMAGE_FORMATS_ARRAY+=("${FORMATS_PART}")

      # Determine code repo for the deployment unit - there may be none
      CODE_DEPLOYMENT_UNIT=$(tr "-" "_" <<< "${DEPLOYMENT_UNIT_PART^^}")
      defineRepoSettings "PRODUCT" "${CODE_DEPLOYMENT_UNIT}" "${PRODUCT}" "${CODE_DEPLOYMENT_UNIT}" "?" "CODE"
      CODE_REPO_ARRAY+=("${NAME_VALUE}")

      # Assume all code covered by one provider for now
      # Remaining code works off this array so easy to change in the future
      CODE_PROVIDER_ARRAY+=("${PRODUCT_CODE_GIT_PROVIDER}")
  done

  # Capture any provided git commit
  case ${AUTOMATION_PROVIDER} in
      jenkins | azurepipelines)
          [[ -n "${GIT_COMMIT}" ]] && CODE_COMMIT_ARRAY[0]="${GIT_COMMIT}"
          ;;
  esac

  # Regenerate the deployment unit list in case the first code commit/tag or format was overriden
  UPDATED_UNITS_ARRAY=()
  for INDEX in $( seq 0 $((${#DEPLOYMENT_UNIT_ARRAY[@]}-1)) ); do
      UPDATED_UNIT=("${DEPLOYMENT_UNIT_ARRAY[$INDEX]}")
      if [[ "${CODE_TAG_ARRAY[$INDEX]}" != "?" ]]; then
          UPDATED_UNIT+=("${CODE_TAG_ARRAY[$INDEX]}")
      else
          if [[ "${CODE_COMMIT_ARRAY[$INDEX]}" != "?" ]]; then
              UPDATED_UNIT+=("${CODE_COMMIT_ARRAY[$INDEX]}")
          fi
      fi
      if [[ "${IMAGE_FORMATS_ARRAY[$INDEX]}" != "?" ]]; then
          UPDATED_UNIT+=("${IMAGE_FORMATS_ARRAY[$INDEX]}")
      fi
      UPDATED_UNITS_ARRAY+=("$(listFromArray "UPDATED_UNIT" "${BUILD_REFERENCE_PART_SEPARATORS}")")
  done
  UPDATED_UNITS=$(listFromArray "UPDATED_UNITS_ARRAY" "${DEPLOYMENT_UNIT_SEPARATORS}")

  # Save for subsequent processing
  save_context_property DEPLOYMENT_UNIT_LIST "${DEPLOYMENT_UNIT_ARRAY[*]}"
  save_context_property CODE_COMMIT_LIST     "${CODE_COMMIT_ARRAY[*]}"
  save_context_property CODE_TAG_LIST        "${CODE_TAG_ARRAY[*]}"
  save_context_property CODE_REPO_LIST       "${CODE_REPO_ARRAY[*]}"
  save_context_property CODE_PROVIDER_LIST   "${CODE_PROVIDER_ARRAY[*]}"
  save_context_property IMAGE_FORMATS_LIST   "${IMAGE_FORMATS_ARRAY[*]}"
  [[ -n "${UPDATED_UNITS}" ]] && save_context_property CLEANED_DEPLOYMENT_UNITS "${UPDATED_UNITS}"

  ### Release management ###

  case "${RELEASE_MODE}" in
      # Promotion details
      ${RELEASE_MODE_SELECTIVE}|${RELEASE_MODE_PROMOTION})
          findAndDefineSetting "FROM_ENVIRONMENT" "PROMOTION_FROM_ENVIRONMENT" "${PRODUCT}" "${ENVIRONMENT}" "value"
          [[ -z "${FROM_ENVIRONMENT}" ]] && findAndDefineSetting "FROM_ENVIRONMENT" "PROMOTION_FROM_SEGMENT" "${PRODUCT}" "${ENVIRONMENT}" "value"
          # Hard code some defaults for now
          if [[ -z "${FROM_ENVIRONMENT}" ]]; then
              case "${ENVIRONMENT}" in
                  staging|preproduction)
                      FROM_ENVIRONMENT="integration"
                      ;;
                  production)
                      FROM_ENVIRONMENT="preproduction"
                      ;;
              esac
              define_context_property "FROM_ENVIRONMENT" "${FROM_ENVIRONMENT}" "lower"
          fi

          findAndDefineSetting "FROM_ACCOUNT" "ACCOUNT" "${PRODUCT}" "${FROM_ENVIRONMENT}" "value"
          if [[ (-n "${FROM_ENVIRONMENT}") &&
                  (-n "${FROM_ACCOUNT}")]]; then
              defineGitProviderSettings    "FROM_ACCOUNT" "" "${FROM_ACCOUNT}" "" "github"
              defineGitProviderSettings    "FROM_PRODUCT" "" "${PRODUCT}" "${FROM_ENVIRONMENT}" "${FROM_ACCOUNT_GIT_PROVIDER}"
              defineRepoSettings           "FROM_PRODUCT" "CONFIG" "${PRODUCT}" "${FROM_ENVIRONMENT}" "${PRODUCT}-cmdb"
              for REGISTRY_TYPE in "${REGISTRY_TYPES[@]}"; do
                  defineRegistryProviderSettings "${REGISTRY_TYPE}" "FROM_PRODUCT" "" "${PRODUCT}" "${FROM_ENVIRONMENT}" "${FROM_ACCOUNT}"
              done
          else
              fatal "PROMOTION environment/account not defined" && exit
          fi
          ;;

      #  Hotfix details
      ${RELEASE_MODE_HOTFIX})
          findAndDefineSetting "FROM_ENVIRONMENT" "HOTFIX_FROM_ENVIRONMENT" "${PRODUCT}" "${ENVIRONMENT}" "value"
          [[ -z "${FROM_ENVIRONMENT}" ]] && findAndDefineSetting "FROM_ENVIRONMENT" "HOTFIX_FROM_SEGMENT" "${PRODUCT}" "${ENVIRONMENT}" "value"
          # Hard code some defaults for now
          if [[ -z "${FROM_ENVIRONMENT}" ]]; then
              case "${ENVIRONMENT}" in
                  *)
                      FROM_ENVIRONMENT="integration"
                      ;;
              esac
              define_context_property "FROM_ENVIRONMENT" "${FROM_ENVIRONMENT}" "lower"
          fi

          findAndDefineSetting "FROM_ACCOUNT" "ACCOUNT" "${PRODUCT}" "${HOTFIX_FROM_ENVIRONMENT}" "value"
          if [[ (-n "${FROM_ENVIRONMENT}") &&
                  (-n "${FROM_ACCOUNT}")]]; then
              for REGISTRY_TYPE in "${REGISTRY_TYPES[@]}"; do
                  defineRegistryProviderSettings "${REGISTRY_TYPE}" "FROM_PRODUCT" "" "${PRODUCT}" "${FROM_ENVIRONMENT}" "${FROM_ACCOUNT}"
              done
          else
              fatal "HOTFIX environment/account not defined" && exit
          fi
          ;;
  esac


  ### Tags ###

      AUTOMATION_RELEASE_IDENTIFIER="${RELEASE_IDENTIFIER:-${AUTOMATION_JOB_IDENTIFIER}}"
      AUTOMATION_DEPLOYMENT_IDENTIFIER="${DEPLOYMENT_IDENTIFIER:-${AUTOMATION_JOB_IDENTIFIER}}"
      if [[ "${AUTOMATION_RELEASE_IDENTIFIER}" =~ ^[0-9]+$ ]]; then
          # If its just a number then add an "r" in front otherwise assume
          # the user is deciding the naming scheme
          AUTOMATION_RELEASE_IDENTIFIER="r${AUTOMATION_RELEASE_IDENTIFIER}"
      fi
      if [[ "${AUTOMATION_DEPLOYMENT_IDENTIFIER}" =~ ^[0-9]+$ ]]; then
          # If its just a number then add an "d" in front otherwise assume
          # the user is deciding the naming scheme
          AUTOMATION_DEPLOYMENT_IDENTIFIER="d${AUTOMATION_DEPLOYMENT_IDENTIFIER}"
      fi

     define_context_property "RELEASE_TAG" "${AUTOMATION_RELEASE_IDENTIFIER}-${DEPLOYMENT_LOCATION}"
     define_context_property "DEPLOYMENT_TAG" "${AUTOMATION_DEPLOYMENT_IDENTIFIER}-${DEPLOYMENT_LOCATION}"

  case "${RELEASE_MODE}" in
      ${RELEASE_MODE_CONTINUOUS})
          # For continuous deployment, the repo isn't tagged with a release
          define_context_property "ACCEPTANCE_TAG" "latest"
          ;;

      ${RELEASE_MODE_SELECTIVE})
          define_context_property "ACCEPTANCE_TAG" "latest"
          ;;

      ${RELEASE_MODE_ACCEPTANCE})
          define_context_property "RELEASE_MODE_TAG" "a${RELEASE_TAG}"
          ;;

      ${RELEASE_MODE_PROMOTION})
          if [[ "${AUTOMATION_RELEASE_IDENTIFIER}" == "branch:*" ]]; then
            define_context_property "ACCEPTANCE_TAG" "${AUTOMATION_RELEASE_IDENTIFIER#"branch:"}"
          else
            define_context_property "ACCEPTANCE_TAG" "${AUTOMATION_RELEASE_IDENTIFIER}-${FROM_ENVIRONMENT}"
          fi

          define_context_property "RELEASE_MODE_TAG" "p${ACCEPTANCE_TAG}-${DEPLOYMENT_LOCATION}"
          ;;

      ${RELEASE_MODE_HOTFIX})
          define_context_property "RELEASE_MODE_TAG" "h${AUTOMATION_RELEASE_IDENTIFIER}-${DEPLOYMENT_LOCATION}"
          define_context_property "ACCEPTANCE_TAG" "latest"
          ;;
  esac


  ### Capture details for logging etc ###

  # Basic details for git commits/slack notification (enhanced by other scripts)
  [[ -n "${PRODUCT}" ]] &&
    DETAIL_MESSAGE="product=${PRODUCT}" ||
    DETAIL_MESSAGE="account=${ACCOUNT}"
  [[ -n "${ENVIRONMENT}" ]]              && DETAIL_MESSAGE="${DETAIL_MESSAGE}, environment=${ENVIRONMENT}"
  [[ ("${SEGMENT}" != "${ENVIRONMENT}") &&
      ("${SEGMENT}" != "default") ]]     && DETAIL_MESSAGE="${DETAIL_MESSAGE}, segment=${SEGMENT}"
  [[ -n "${TIER}" ]]                     && DETAIL_MESSAGE="${DETAIL_MESSAGE}, tier=${TIER}"
  [[ -n "${COMPONENT}" ]]                && DETAIL_MESSAGE="${DETAIL_MESSAGE}, component=${COMPONENT}"
  [[ "${#DEPLOYMENT_UNIT_ARRAY[@]}" -ne 0 ]] && DETAIL_MESSAGE="${DETAIL_MESSAGE}, units=${UPDATED_UNITS}"
  [[ -n "${TASK}" ]]                     && DETAIL_MESSAGE="${DETAIL_MESSAGE}, task=${TASK}"
  [[ -n "${TASKS}" ]]                    && DETAIL_MESSAGE="${DETAIL_MESSAGE}, tasks=${TASKS}"
  [[ -n "${GIT_USER}" ]]                 && DETAIL_MESSAGE="${DETAIL_MESSAGE}, user=${GIT_USER}"
  [[ -n "${DEPLOYMENT_MODE}" ]]          && DETAIL_MESSAGE="${DETAIL_MESSAGE}, mode=${DEPLOYMENT_MODE}"
  [[ -n "${COMMENT}" ]]                  && DETAIL_MESSAGE="${DETAIL_MESSAGE}, comment=${COMMENT}"

  save_context_property DETAIL_MESSAGE

  ### Remember automation details ###

  save_context_property AUTOMATION_BASE_DIR
  save_context_property AUTOMATION_PROVIDER
  save_context_property AUTOMATION_PROVIDER_DIR
  save_context_property AUTOMATION_DIR
  save_context_property AUTOMATION_DATA_DIR
  save_context_property AUTOMATION_BUILD_DIR
  save_context_property AUTOMATION_BUILD_SRC_DIR
  save_context_property AUTOMATION_BUILD_DEVOPS_DIR
  save_context_property AUTOMATION_JOB_IDENTIFIER
  save_context_property AUTOMATION_RELEASE_IDENTIFIER
  save_context_property AUTOMATION_DEPLOYMENT_IDENTIFIER

  # All good
  RESULT=0
}

main "$@"

