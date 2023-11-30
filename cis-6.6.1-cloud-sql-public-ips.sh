#!/bin/bash

source common-constants.inc;
source functions.inc;

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
    "--project")   		set -- "$@" "-p" ;;
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

if [[ $CSV == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"DATABASE_NAME\", \"DATABASE_VERSION\", \"EXTERNAL_IP\", \"EXTERNAL_IP_EXISTS_FLAG\"";
fi;

for PROJECT_ID in $PROJECT_IDS; do

	set_project $PROJECT_ID;

	if ! api_enabled sqladmin.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "Cloud SQL API is not enabled on Project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
		continue;
	fi;	

	declare INSTANCES=$(gcloud sql instances list --quiet --format="json");

	if [[ $DEBUG == "True" ]]; then
		echo "Cloud SQL Instances (json): $INSTANCES";
		echo $BLANK_LINE;
	fi;
	
	if [[ $INSTANCES != "[]" ]]; then

		# Note: tr -d "\\" was added because Google returns errant backslashes in the field containing the  certificate value
		echo $INSTANCES | jq -rc '.[]' | tr -d "\\" 2>/dev/null | while IFS='' read INSTANCE;do
		
			if [[ $DEBUG == "True" ]]; then
				echo "Cloud SQL Instance (json): $INSTANCE";
				echo $BLANK_LINE;
			fi;

			DATABASE_NAME=$(echo $INSTANCE | jq -rc '.name');	
			DATABASE_VERSION=$(echo $INSTANCE | jq -rc '.databaseVersion');
			EXTERNAL_IP=$(echo $INSTANCE | jq -rc '.ipAddresses[]' | jq 'select(.type == "PRIMARY")' | jq '.ipAddress');
			
			EXTERNAL_IP_EXISTS_FLAG="False";
			if [[ $EXTERNAL_IP == "" ]]; then
				EXTERNAL_IP="No external IP found";
			else
				EXTERNAL_IP_EXISTS_FLAG="True";
			fi;
	
			# Get project details
	      		get_project_details $PROJECT_ID

			if [[ $CSV != "True" ]]; then
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";
				echo "Cloud SQL Instance $DATABASE_NAME";
				echo "Version: $DATABASE_VERSION";
				echo "External IP Addresses: $EXTERNAL_IP";
				echo $BLANK_LINE;
			else
				echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$DATABASE_NAME\", \"$DATABASE_VERSION\", \"$EXTERNAL_IP\", \"$EXTERNAL_IP_EXISTS_FLAG\"";
			fi;

		done;
	
	else
		if [[ $CSV != "True" ]]; then
			echo "Project $PROJECT_ID: No Cloud SQL found. Disable the Cloud SQL API until needed.";
			echo $BLANK_LINE;
		fi;
	fi;
		
	sleep $SLEEP_SECONDS;
done;

