#!/bin/bash

source common-constants.inc;
source functions.inc;

PROJECT_IDS="";
DEBUG="False";
HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 		set -- "$@" "-h" ;;
    "--debug") 		set -- "$@" "-d" ;;
    "--project")   	set -- "$@" "-p" ;;
    *)        		set -- "$@" "$arg"
  esac
done

while getopts "hdp:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_IDS=${OPTARG};;
        d)
        	DEBUG="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;

declare SEPARATOR="----------------------------------------------------------------------------------------";

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

for PROJECT_ID in $PROJECT_IDS; do

	set_project $PROJECT_ID;

	if ! api_enabled cloudfunctions.googleapis.com; then
		echo "Cloud Functions not enabled for Project $PROJECT_ID.";
		continue;
	fi
	
	declare RESULTS=$(gcloud functions list --quiet --format="json");

	if [[ $RESULTS != "[]" ]]; then
		
		# Get project details
    		get_project_details $PROJECT_ID

		echo $SEPARATOR;
		echo "Cloud functions for project $PROJECT_ID";
		echo "Project Application: $PROJECT_APPLICATION";
		echo "Project Owner: $PROJECT_OWNER";
		echo $BLANK_LINE;
		
		echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r CLOUD_FUNCTION;do
		
			NAME=$(echo $CLOUD_FUNCTION | jq -rc '.name' | cut -d '/' -f 6);
			BUILD_ENIVRONMENT_VARIABLES=$(echo $CLOUD_FUNCTION | jq '.buildEnvironmentVariables');
			ENIVRONMENT_VARIABLES=$(echo $CLOUD_FUNCTION | jq '.environmentVariables');
			INGRESS_SETTINGS=$(echo $CLOUD_FUNCTION | jq '.ingressSettings');

			echo "Name: $NAME";
			echo "Build Environment Variables: $BUILD_ENIVRONMENT_VARIABLES";
			echo "Environment Variables: $ENIVRONMENT_VARIABLES";
			if [[ $INGRESS_SETTINGS =~ "ALLOW_ALL" ]]; then echo "VIOLATION: Cloud function allows all ingress"; fi;
			echo $BLANK_LINE;
		done;
	else
		echo $SEPARATOR;
		echo "No cloud functions found for $PROJECT_ID";
		echo $BLANK_LINE;
	fi;
	sleep $SLEEP_SECONDS;
done;

