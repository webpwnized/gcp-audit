#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)

for PROJECT_ID in $PROJECT_IDS; do
	gcloud config set project $PROJECT_ID 1&>/dev/null;
	declare RESULTS=$(gcloud compute networks list --quiet --format="flattened(NAME,SUBNET_MODE)");
	if [[ $RESULTS =~ .*default* ]]
	then
	:
		echo "Default Networks for Project $PROJECT_ID";
		echo $RESULTS;
		echo "";
	elif [[ $RESULTS =~ .*LEGACY* ]] 
	then
		echo "Legacy Networks for Project $PROJECT_ID";
		echo $RESULTS;		
		echo "";
	fi
done;
