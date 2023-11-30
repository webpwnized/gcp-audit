#!/bin/bash

source common-constants.inc;
source functions.inc;

declare SEPARATOR="---------------------------------------------------------------------------------";
declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-c, --csv] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 			set -- "$@" "-h" ;;
    "--debug") 			set -- "$@" "-d" ;;
    "--csv") 			set -- "$@" "-c" ;;
    "--project")	   	set -- "$@" "-p" ;;
    *)        			set -- "$@" "$arg"
  esac
done

while getopts "hdcp:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_IDS=${OPTARG};;
        d)
        	DEBUG="True";;
        c)
        	CSV="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

if [[ $DEBUG == "True" ]]; then
	echo "Projects: $PROJECT_IDS";
	echo $BLANK_LINE;
fi;

if [[ $CSV == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"INSTANCE_NAME\", \"SERVICE_ACCOUNTS\", \"IS_SA_VIOLATION\", \"IS_ROLE_VIOLATION\", \"ROLES\", \"ROLES_STATUS_MESSAGE\", \"SERVICE_ACCOUNT_STATUS_MESSAGE\", \"SCOPES\"";
fi;

for PROJECT_ID in $PROJECT_IDS; do	

	set_project $PROJECT_ID;
	
	if ! api_enabled compute.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "Compute Engine API is not enabled on Project $PROJECT_ID";
		fi;
		continue;
	fi;
	
 	declare INSTANCES=$( gcloud compute instances list --quiet --format="json");

	if [[ $DEBUG == "True" ]]; then
		echo "Instances (JSON): $INSTANCES";
		echo $BLANK_LINE;
	fi;

	if [[ $INSTANCES != "[]" ]]; then

      		#Get project details
      		get_project_details $PROJECT_ID

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do
		
			if [[ $DEBUG == "True" ]]; then
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";			
				echo "Instance (JSON): $INSTANCE";
			fi;
			
			INSTANCE_NAME=$(echo $INSTANCE | jq -rc '.name');
			SERVICE_ACCOUNTS=$(echo $INSTANCE | jq -rc '.serviceAccounts[].email');
			IS_GKE_NODE=$(echo $INSTANCE | jq '.labels' | jq 'has("goog-gke-node")');
			SCOPES=$(echo $INSTANCE | jq -rc '.serviceAccounts[].scopes[]');
			ROLES=$(gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --filter="bindings.members:$SERVICE_ACCOUNTS" --format="json" | jq '.[]' | jq '.bindings.role');
			
			# Determine if the default service account is in use
			if [[ $SERVICE_ACCOUNTS =~ [-]compute[@]developer[.]gserviceaccount[.]com && $IS_GKE_NODE == "false" ]]; then
				IS_SA_VIOLATION="True";
				SERVICE_ACCOUNT_STATUS_MESSAGE="VIOLATION: Default Service Account detected";
			else			
				IS_SA_VIOLATION="False";
				SERVICE_ACCOUNT_STATUS_MESSAGE="NOTICE: Custom Service Account Detected";
			fi;

			if [[ $ROLES =~ editor ]]; then
				IS_ROLE_VIOLATION="True";
				ROLES_STATUS_MESSAGE="VIOLATION: Service account has Editor permission";
			else			
				IS_ROLE_VIOLATION="False";
				ROLES_STATUS_MESSAGE="NOTICE: Service account has custom permissions";
			fi;		
						
			if [[ $CSV != "True" ]]; then
				echo "Project ID: $PROJECT_ID";
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";
				echo "Instance Name: $INSTANCE_NAME";
				echo "Service Accounts: $SERVICE_ACCOUNTS";
				echo "Status: $SERVICE_ACCOUNT_STATUS_MESSAGE";
				echo "Google OAuth Scopes:";
				echo $SCOPES;
				echo "Roles: $ROLES";
				echo "$ROLES_STATUS_MESSAGE";
				echo $BLANK_LINE;
			else
				echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$INSTANCE_NAME\", \"$SERVICE_ACCOUNTS\", \"$IS_SA_VIOLATION\", \"$IS_ROLE_VIOLATION\", \"$ROLES\", \"$ROLES_STATUS_MESSAGE\", \"$SERVICE_ACCOUNT_STATUS_MESSAGE\", \"$SCOPES\"";
			fi;		
		done;
	else
		if [[ $CSV != "True" ]]; then
			echo "No instances found for project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
	fi;
	sleep $SLEEP_SECONDS;
done;

