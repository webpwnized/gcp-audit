#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)

for PROJECT_ID in $PROJECT_IDS; do	
	gcloud config set project $PROJECT_ID;
	declare INSTANCES=$( gcloud compute instances list --quiet --format="json");

	if [[ $INSTANCES != "[]" ]]; then
	
		echo "---------------------------------------------------------------------------------";
		echo "Instances for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do
		
			NAME=$(echo $INSTANCE | jq -rc '.name');
			SERVICE_ACCOUNTS=$(echo $INSTANCE | jq -rc '.serviceAccounts[].email');
			IS_GKE_NODE=$(echo $INSTANCE | jq '.labels' | jq 'has("goog-gke-node")');

			echo "Instance Name: $NAME";
			echo "Service Accounts: $SERVICE_ACCOUNTS";
			
			if [[ $SERVICE_ACCOUNTS =~ [-]compute[@]developer[.]gserviceaccount[.]com && $IS_GKE_NODE == "false" ]]; then
				echo "Violation: Default Service Account detected"
			fi;
			echo "";
		done;
		echo "";
	else
		echo "No instances found for Project $PROJECT_ID";
		echo "";
	fi;
	sleep 0.5;
done;

