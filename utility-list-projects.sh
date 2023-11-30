#!/bin/bash

declare RESULTS=$(gcloud projects list --format="json");

if [[ $RESULTS != "[]" ]]; then
		
	echo $RESULTS | jq -rc '.[]' | while IFS='' read PROJECT;do

		NAME=$(echo $PROJECT | jq '.name');
		APPLICATION=$(echo $PROJECT | jq '.labels.app');
		OWNER=$(echo $PROJECT | jq '.labels.adid');
		
		echo "Name: $NAME";
		if [[ $APPLICATION != "null" ]]; then echo "Application: $APPLICATION"; fi;		
		if [[ $OWNER != "null" ]]; then echo "Owner: $OWNER"; fi;
		echo $BLANK_LINE;
		sleep $SLEEP_SECONDS;
	done;
else
	echo "No projects found";
	echo $BLANK_LINE;
fi;

