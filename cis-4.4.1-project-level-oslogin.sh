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

for PROJECT_ID in $PROJECT_IDS; do	
	gcloud config set project $PROJECT_ID;
	declare PROJECT_INFO=$(gcloud compute project-info describe --format="json");

	if [[ $PROJECT_INFO != "" ]]; then
	
		echo "---------------------------------------------------------------------------------";
		echo "Project information for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		OSLOGIN_ENABLED=$(echo $PROJECT_INFO | jq -rc '.commonInstanceMetadata.items[] | with_entries( .value |= ascii_downcase ) | select(.key=="enable-oslogin") | select(.value=="true")' );

		if [[ $OSLOGIN_ENABLED == "" ]]; then
			echo "Project Name: $PROJECT_ID";
			echo "VIOLATION: OS Login is NOT enabled at the Project level"
		fi;
		echo "";
	else
		echo "No project information found for Project $PROJECT_ID";
		echo "";
	fi;
	sleep 0.5;
done;

