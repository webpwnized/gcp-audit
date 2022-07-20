#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)

for PROJECT_ID in $PROJECT_IDS; do	
	gcloud config set project $PROJECT_ID;
	declare SERVICES=$(gcloud run services list --quiet --format="json");

	if [[ $SERVICES != "[]" ]]; then
	
		echo "---------------------------------------------------------------------------------";
		echo "SERVICES for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		echo $SERVICES | jq -rc '.[]' | while IFS='' read -r SERVICE;do
		
			echo $SERVICE | jq -rc '.';
		
			NAME=$(echo $SERVICE | jq -rc '.name');
						
			if [[ $NAME != "" ]]; then
				echo "SERVICE Name: $NAME";
			fi;
			echo "";
		done;
		echo "";
	else
		echo "No SERVICES found for Project $PROJECT_ID";
		echo "";
	fi;
	sleep 0.5;
done;

