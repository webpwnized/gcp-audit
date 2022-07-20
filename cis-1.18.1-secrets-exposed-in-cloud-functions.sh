#!/bin/bash

LONG=project:
SHORT=p:
OPTS=$(getopt -a -n testscript --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"
while :
do
    case "$1" in --project | -p )
        declare PROJECT_IDS="$2"
        shift 2
     ;;
     -- )
        shift;
        break
        ;;
        *)
        exit 2
    esac
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

declare SEPARATOR="----------------------------------------------------------------------------------------";

for PROJECT_ID in $PROJECT_IDS; do

	gcloud config set project $PROJECT_ID;

	declare RESULTS=$(gcloud functions list --quiet --format="json");

	if [[ $RESULTS != "[]" ]]; then
		
		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

		echo $SEPARATOR;
		echo "Cloud functions for project $PROJECT_ID";
		echo "Project Name: $PROJECT_NAME";
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

