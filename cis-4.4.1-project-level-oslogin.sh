#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)

for PROJECT_ID in $PROJECT_IDS; do	
	gcloud config set project $PROJECT_ID;
	declare PROJECT_INFO=$(gcloud compute project-info describe --format="json");

	if [[ $PROJECT_INFO != "" ]]; then
	
		echo "---------------------------------------------------------------------------------";
		echo "Project information for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		OSLOGIN_ENABLED=$(echo $PROJECT_INFO | jq -rc '.commonInstanceMetadata.items[] | select(.key=="enable-oslogin") | select(.value=="TRUE")' );

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

