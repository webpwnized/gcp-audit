#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)

for PROJECT_ID in $PROJECT_IDS; do
	echo "Project $PROJECT_ID"
	declare ACCOUNTS=$(gcloud projects get-iam-policy $PROJECT_ID --format=json | jq -r '.bindings[] | .role, .members[]')
	for ACCOUNT in $ACCOUNTS; do
		if [[ $ACCOUNT =~ 'roles' ]]; then
			echo ""
			echo ""
			echo $ACCOUNT
			echo "----------------------------"
		else
			echo $ACCOUNT
		fi
	done;
	echo ""
done;
