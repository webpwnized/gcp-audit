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

	PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
	PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
	PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

	gcloud config set project $PROJECT_ID;
	declare PROJECT_INFO=$(gcloud compute project-info describe --format="json");

	if [[ $PROJECT_INFO != "" ]]; then
	
		echo "---------------------------------------------------------------------------------";
		echo "Project information for Project $PROJECT_ID";
        	echo "Project Application: $PROJECT_APPLICATION";
        	echo "Project Owner: $PROJECT_OWNER";
		echo "---------------------------------------------------------------------------------";

		# Checking the project level confirguration
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

	# Checking the instance level configuration	
	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	if [[ $INSTANCES != "[]" ]]; then
		
		echo "---------------------------------------------------------------------------------";
		echo "Instances for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do

			NAME=$(echo $INSTANCE | jq -rc '.name');			
			OSLOGIN_CONFIGURED=$(echo $INSTANCE | jq -rc '.metadata.items[] | with_entries( .value |= ascii_downcase ) | select(.key=="enable-oslogin")' );
		
			if [[ $OSLOGIN_CONFIGURED != "" ]]; then
				echo "Instance Name: $NAME";
				echo "VIOLATION: OS Login is enabled at the instance level. OS Login must only be enabled at the project level";
				echo "";
			fi;
		done;
		echo "";
	else
		echo "No instances found for Project $PROJECT_ID";
		echo "";
	fi;

	sleep 0.5;
done;

