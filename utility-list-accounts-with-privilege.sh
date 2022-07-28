#!/bin/bash

ROLE=$1

if [[ $ROLE == "" ]]; then
	ROLE="owner";
fi;

declare PROJECTS=$(gcloud projects list --format="json");

if [[ $PROJECTS != "[]" ]]; then
		
	echo $PROJECTS | jq -rc '.[]' | while IFS='' read PROJECT;do

		PROJECT_NAME=$(echo $PROJECT | jq -r '.name');
		PROJECT_OWNER=$(echo $PROJECT | jq -r '.labels.adid');
		PROJECT_APPLICATION=$(echo $PROJECT | jq -r '.labels.app');
		MEMBERS=$(gcloud projects get-iam-policy $PROJECT_NAME --format="json" | jq -r '.bindings[] | 	select(.role=="roles/'$ROLE'") | .members[]');

		if [[ $MEMBERS != "" ]]; then
			echo "Project Name: $PROJECT_NAME";
			echo "Project Owner: $PROJECT_OWNER";
			echo "Project Application: $PROJECT_APPLICATION";			
			echo -e "Members ($ROLE role):\n$MEMBERS";
			echo "";
		fi;
	done;
else
	echo "No projects found";
	echo "";
fi;
