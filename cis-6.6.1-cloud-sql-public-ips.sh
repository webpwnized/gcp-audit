#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)

for PROJECT_ID in $PROJECT_IDS; do	
	gcloud config set project $PROJECT_ID;
	declare INSTANCES=$(gcloud sql instances list --quiet --format="json");

	DATABASE_NAME=$(echo $INSTANCES | jq '.[]' | jq '.name');	
	DATABASE_VERSION=$(echo $INSTANCES | jq '.[]' | jq '.databaseVersion');
	EXTERNAL_IP=$(echo $INSTANCES | jq '.[]' | jq '.ipAddresses[]' | jq 'select(.type == "PRIMARY")' | jq '.ipAddress');
	
	if [[ $DATABASE_NAME != "" ]]; then
		echo "Cloud SQL instances for Project $PROJECT_ID";
		echo "";
		echo "Cloud SQL Instance $DATABASE_NAME";
		echo "Version: $DATABASE_VERSION";
		if [[ $EXTERNAL_IP != "" ]]; then
			echo "External IP Addresses: $EXTERNAL_IP";
		else
			echo "No external IP found";
		fi
		echo "";
		sleep 1;
	else
		echo "Project $PROJECT_ID: No Cloud SQL found";
	fi
done;
