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
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"BUCKET_NAME\", \"MEMBERS\", \"ROLE\", \"ALL_USERS_MESSAGE\", \"ALL_AUTHENTICATED_USERS_MESSAGE\"";
fi;

for PROJECT_ID in $PROJECT_IDS; do

	set_project $PROJECT_ID;

	if ! api_enabled storage.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "Storage API is not enabled on Project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
		continue;
	fi;

	declare BUCKET_NAMES=$(gsutil ls);
	
	if [[ $DEBUG == "True" ]]; then
		echo "Buckets: $BUCKET_NAMES";
		echo $BLANK_LINE;
	fi;

	if [[ $BUCKET_NAMES != "" ]]; then

      		#Get project details
      		get_project_details $PROJECT_ID

		for BUCKET_NAME in $BUCKET_NAMES; do

			declare PERMISSIONS=$(gsutil iam get $BUCKET_NAME);

			if [[ $DEBUG == "True" ]]; then
				echo "Permissions (JSON): $PERMISSIONS";
			fi;

			echo $PERMISSIONS | jq -r -c '.bindings[]' | while IFS='' read -r PERMISSION;do

				MEMBERS=$(echo $PERMISSION | jq -rc '.members[]');
				ROLE=$(echo $PERMISSION | jq '.role');

				if [[ $ROLE =~ "allUsers" ]]; then
					ALL_USERS_MESSAGE="VIOLATION: Bucket publicly exposed to allUsers";
				else
					ALL_USERS_MESSAGE="OK: The allUsers group does not have permission to the bucket"; 
				fi;

				if [[ $ROLE =~ "allAuthenticatedUsers" ]]; then
					ALL_AUTHENTICATED_USERS_MESSAGE="VIOLATION: Bucket publicly exposed to allAuthenticatedUsers";
				else
					ALL_AUTHENTICATED_USERS_MESSAGE="OK: The allAuthenticatedUsers group does not have permission to the bucket";
				fi;

				if [[ $CSV != "True" ]]; then
					echo "Project ID: $PROJECT_ID";
					echo "Project Name: $PROJECT_NAME";
					echo "Project Application: $PROJECT_APPLICATION";
					echo "Project Owner: $PROJECT_OWNER";
					echo "Bucket Name: $BUCKET_NAME";
					echo "Members: $MEMBERS";
					echo "Role: $ROLE";
					echo "$ALL_USERS_MESSAGE";
					echo "$ALL_AUTHENTICATED_USERS_MESSAGE";
					echo $BLANK_LINE;
				else
					echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$BUCKET_NAME\", \"$MEMBERS\", \"$ROLE\", \"$ALL_USERS_MESSAGE\", \"$ALL_AUTHENTICATED_USERS_MESSAGE\"";
				fi;
			done;
		done;
		echo $BLANK_LINE;
	else
		if [[ $CSV != "True" ]]; then
			echo "No storage buckets found for Project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
	fi;
	sleep $SLEEP_SECONDS;
done;

