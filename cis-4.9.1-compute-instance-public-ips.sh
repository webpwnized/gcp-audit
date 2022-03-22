#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)
#declare PROJECT_IDS="dev-gke-playground-qjj1pwc";
#declare PROJECT_IDS="gcp-soc-lab-uat";

for PROJECT_ID in $PROJECT_IDS; do
	echo "Compute Instances for Project $PROJECT_ID";
	echo "";
	
	gcloud config set project $PROJECT_ID;
	declare INSTANCES=$(gcloud compute instances list --quiet --format="csv(NAME,ZONE)");

	for INSTANCE in $INSTANCES; do
		NAME=$(echo $INSTANCE | cut -d "," -f1);
		ZONE=$(echo $INSTANCE | cut -d "," -f2 | cut -d / -f7);

		if [[ $ZONE != "zone" ]]; then
			echo "Project $PROJECT_ID";
			echo "External network interfaces for Instance $NAME";
			echo "";
			gcloud compute instances describe $NAME --zone $ZONE --format="json" | jq '.name,.networkInterfaces[].accessConfigs';
			echo "";
			sleep 1;
		fi
	done;
done;
