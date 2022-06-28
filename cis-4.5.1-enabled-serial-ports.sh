#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)

for PROJECT_ID in $PROJECT_IDS; do	
	gcloud config set project $PROJECT_ID;
	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	if [[ $INSTANCES != "[]" ]]; then
	
		echo "---------------------------------------------------------------------------------";
		echo "Instances for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do

			NAME=$(echo $INSTANCE | jq -rc '.name');
			ENABLED_SERIAL_PORTS=$(echo $INSTANCE | jq -rc '.metadata.items[] | select(.key=="serial-port-enable")' | jq -rc '.value' | tr '[:upper:]' '[:lower:]' );
			
			if [[ $ENABLED_SERIAL_PORTS != "0" && $ENABLED_SERIAL_PORTS != "" ]]; then
				echo "Instance Name: $NAME";
				echo "Serial Port Setting: $ENABLED_SERIAL_PORTS";
				echo "VIOLATION: Serial port enabled"
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

