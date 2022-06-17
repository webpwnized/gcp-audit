#!/bin/bash

declare RESULTS=$(gcloud projects list --format="json");

if [[ $RESULTS != "[]" ]]; then
		
	echo $RESULTS | jq -rc '.[]' | while IFS='' read PROJECT;do

		NAME=$(echo $PROJECT | jq '.name');
		APPLICATION=$(echo $PROJECT | jq '.labels.app');
		OWNER=$(echo $PROJECT | jq '.labels.adid');
		
		echo "$NAME: $OWNER";
	done;
else
	echo "No projects found";
	echo "";
fi;

