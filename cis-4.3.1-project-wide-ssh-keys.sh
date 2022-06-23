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
			BLOCK_PROJECT_WIDE_SSH_KEYS=$(echo $INSTANCE | jq -rc '.metadata.items[] | select(.key=="block-project-ssh-keys")' | jq -rc '.value' );
						
			if [[ $BLOCK_PROJECT_WIDE_SSH_KEYS != "true" ]]; then
				echo "Instance Name: $NAME";
				echo "VIOLATION: Project-wide SSH keys allowed"
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

