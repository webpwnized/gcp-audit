#!/bin/bash

declare RESULTS=$(gcloud projects list --format="json");

if [[ $RESULTS != "[]" ]]; then
		
	echo $RESULTS | jq -rc '.[]' | while IFS='' read PROJECT;do

		NAME=$(echo $PROJECT | jq -rc '.name');
		APPLICATION=$(echo $PROJECT | jq -rc '.labels.app');
		OWNER=$(echo $PROJECT | jq -rc '.labels.adid');
		
		echo "$NAME: $OWNER";
	done;
else
	echo "No projects found";
	echo "";
fi;

