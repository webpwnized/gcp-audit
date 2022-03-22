#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)

for PROJECT_ID in $PROJECT_IDS; do	
	gcloud config set project $PROJECT_ID;
	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	INSTANCE_NAME=$(echo $INSTANCES | jq '.[]' | jq '.name');	
	EXTERNAL_IP=$(echo $INSTANCES | jq '.[]' | jq '.networkInterfaces[].accessConfigs[]');
	
	if [[ $INSTANCE_NAME != "" ]]; then
		echo "Compute instances for Project $PROJECT_ID";
		echo "";
		echo "Compute instance $INSTANCE_NAME";
		if [[ $EXTERNAL_IP != "" ]]; then
			echo "External IP Addresses: $EXTERNAL_IP";
		else
			echo "No external IP found";
		fi
		echo "";
		sleep 1;
	else
		echo "Project $PROJECT_ID: No compute instance found";
	fi
done;

