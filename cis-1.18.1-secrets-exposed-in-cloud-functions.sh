#!/bin/bash

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
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

for PROJECT_ID in $PROJECT_IDS; do

	gcloud config set project $PROJECT_ID;

	if [[ $(gcloud services list --enabled | grep -c -e cloudfunctions.googleapis.com) == 0 ]]; then
		echo "Cloud Functions not enabled.";
		continue;
	fi;

	declare RESULTS=$(gcloud functions list --quiet --format="json");

	if [[ $RESULTS != "[]" ]]; then
		
		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

		echo $SEPARATOR;
		echo "Cloud functions for project $PROJECT_ID";
		echo "Project Application: $PROJECT_APPLICATION";
		echo "Project Owner: $PROJECT_OWNER";
		echo "";
		
		echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r CLOUD_FUNCTION;do
		
			NAME=$(echo $CLOUD_FUNCTION | jq -rc '.name' | cut -d '/' -f 6);
			BUILD_ENIVRONMENT_VARIABLES=$(echo $CLOUD_FUNCTION | jq '.buildEnvironmentVariables');
			ENIVRONMENT_VARIABLES=$(echo $CLOUD_FUNCTION | jq '.environmentVariables');
			INGRESS_SETTINGS=$(echo $CLOUD_FUNCTION | jq '.ingressSettings');

			echo "Name: $NAME";
			echo "Build Environment Variables: $BUILD_ENIVRONMENT_VARIABLES";
			echo "Environment Variables: $ENIVRONMENT_VARIABLES";
			if [[ $INGRESS_SETTINGS =~ "ALLOW_ALL" ]]; then echo "VIOLATION: Cloud function allows all ingress"; fi;
			echo "";
		done;
	else
		echo $SEPARATOR;
		echo "No cloud functions found for $PROJECT_ID";
		echo "";
	fi;
	sleep 0.5;
done;

