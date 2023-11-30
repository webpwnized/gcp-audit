#!/bin/bash

source common-constants.inc;
source functions.inc;

declare SEPARATOR="---------------------------------------------------------------------------------";
declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [--csv] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 		set -- "$@" "-h" ;;
    "--debug") 		set -- "$@" "-d" ;;
    "--csv") 		set -- "$@" "-c" ;;
    "--project")   	set -- "$@" "-p" ;;
    *)        		set -- "$@" "$arg"
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

for PROJECT_ID in $PROJECT_IDS; do	

	set_project $PROJECT_ID;
	
	if ! api_enabled appengine.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "App Engine API is not enabled on Project $PROJECT_ID";
		fi;
		continue;
	fi;

 	declare APPLICATION=$(gcloud app describe --quiet --format="json" 2>/dev/null);

	if [[ $DEBUG == "True" ]]; then
		echo "Application (JSON): $APPLICATION";
		echo $BLANK_LINE;
	fi;

	if [[ $APPLICATION != "" ]]; then

		#Get project details
      		get_project_details $PROJECT_ID

		if [[ $DEBUG == "True" ]]; then
			echo "Project Name: $PROJECT_NAME";
			echo "Project Application: $PROJECT_APPLICATION";
			echo "Project Owner: $PROJECT_OWNER";			
			echo "Application (JSON): $APPLICATION";
		fi;
						
		APPLICATION_NAME=$(echo $APPLICATION | jq -rc '.name');
		SERVICE_ACCOUNT=$(echo $APPLICATION | jq -rc '.serviceAccount');
		CODE_BUCKET=$(echo $APPLICATION | jq -rc '.codeBucket');
		DEFAULT_BUCKET=$(echo $APPLICATION | jq -rc '.defaultBucket');
		DEFAULT_HOSTNAME=$(echo $APPLICATION | jq -rc '.defaultHostname');
		SERVING_STATUS=$(echo $APPLICATION | jq -rc '.servingStatus');
		
		ROLES=$(gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --filter="bindings.members:$SERVICE_ACCOUNT" --format="json" | jq '.[]' | jq '.bindings.role');
		
		# Determine if the default service account is in use
		if [[ $SERVICE_ACCOUNT == "$PROJECT_ID@appspot.gserviceaccount.com" ]]; then
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
			echo "Application Name: $APPLICATION_NAME";
			echo "Hostname: $DEFAULT_HOSTNAME";
			echo "Code Bucket: $CODE_BUCKET";
			echo "Default Bucket: $DEFAULT_BUCKET";
			echo "Serving Status: $SERVING_STATUS";
			echo "Service Accounts: $SERVICE_ACCOUNT";
			echo "Service Account Status: $SERVICE_ACCOUNT_STATUS_MESSAGE";
			echo "Roles: $ROLES";
			echo "$ROLES_STATUS_MESSAGE";
			echo $BLANK_LINE;
		else
			echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$APPLICATION_NAME\", \"$DEFAULT_HOSTNAME\", \"$CODE_BUCKET\", \"$DEFAULT_BUCKET\", \"$SERVING_STATUS\", \"$SERVICE_ACCOUNT\", \"$SERVICE_ACCOUNT_STATUS_MESSAGE\", $ROLES, \"$ROLES_STATUS_MESSAGE\"";
		fi;		
	else
		if [[ $CSV != "True" ]]; then
			echo "No application found for project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
	fi;
	sleep $SLEEP_SECONDS;
done;

