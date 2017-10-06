#!/bin/bash

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${GENERATION_DIR}/common.sh"

# Generate the deployment template for the required deployment unit

# Process the deployment units
for LEVEL in segment solution; do
    DEPLOYMENT_UNITS="${LEVEL^^}_DEPLOYMENT_UNITS"
    for DEPLOYMENT_UNIT in ${!DEPLOYMENT_UNITS}; do
    
    	# Generate the template if required
    	cd $(findGen3SegmentDir "${AUTOMATION_DATA_DIR}/${ACCOUNT}" "${PRODUCT}" "${SEGMENT}")
        case ${MODE} in
            create|update)
   	            ${GENERATION_DIR}/create${LEVEL^}Template.sh -u ${DEPLOYMENT_UNIT}
                RESULT=$?
                [[ "${RESULT}" -ne 0 ]] &&
                    fatal "Generation of the ${LEVEL} level template for the ${DEPLOYMENT_UNIT} deployment unit of the ${SEGMENT} segment failed"
		    ;;
        esac
        
        # Manage the stack
        ${GENERATION_DIR}/${MODE}Stack.sh -t ${LEVEL} -u ${DEPLOYMENT_UNIT}
	    RESULT=$?
        [[ "${RESULT}" -ne 0 ]] &&
            fatal "Applying ${MODE} mode to the ${LEVEL} level stack for the ${DEPLOYMENT_UNIT} deployment unit of the ${SEGMENT} segment failed"
        
		# Update the infrastructure repo to capture any stack changes
        ${AUTOMATION_DIR}/manageRepo.sh -p \
            -d ${AUTOMATION_DATA_DIR}/${ACCOUNT}/infrastructure/${PRODUCT} \
            -l "infrastructure" \
            -m "Stack changes as a result of applying ${MODE} mode to the ${LEVEL} level stack for the ${DEPLOYMENT_UNIT} deployment unit of the ${SEGMENT} segment"
            
	    RESULT=$?
        [[ "${RESULT}" -ne 0 ]] &&
            fatal "Unable to save the changes resulting from applying ${MODE} mode to the ${LEVEL} level stack for the ${DEPLOYMENT_UNIT} deployment unit of the ${SEGMENT} segment"
    done
done

# Check credentials if required
if [[ "${CHECK_CREDENTIALS}" == "true" ]]; then
    cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}
    SEGMENT_OPTION=""
    [[ -n "${SEGMENT}" ]] && SEGMENT_OPTION="-s ${SEGMENT}"

    ${GENERATION_DIR}/initProductCredentials.sh -a ${ACCOUNT} -p ${PRODUCT} ${SEGMENT_OPTION}

    # Update the infrastructure repo to capture any credential changes
    cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}/infrastructure/${PRODUCT}

	# Ensure git knows who we are
    git config user.name  "${GIT_USER}"
    git config user.email "${GIT_EMAIL}"
 
    # Record changes
    git add *
    git commit -m "Credential updates for the ${SEGMENT} segment"
    git push origin master
	RESULT=$?
    [[ "${RESULT}" -ne 0 ]] &&
        fatal "Unable to save the credential updates for the ${SEGMENT} segment"
fi

# Update the code and credentials buckets if required
if [[ "${SYNC_BUCKETS}" == "true" ]]; then
    cd ${AUTOMATION_DATA_DIR}/${ACCOUNT}
    ${GENERATION_DIR}/syncAccountBuckets.sh -a ${ACCOUNT}
fi



