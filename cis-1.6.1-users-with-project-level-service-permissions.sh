#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)

for PROJECT_ID in $PROJECT_IDS; do
	echo "Users with Project Level Service Account Permissions for Project $PROJECT_ID"
	echo ""
	echo "Project level service account user permissions"
	gcloud projects get-iam-policy $PROJECT_ID --format json | jq '.bindings[].role' | grep "roles/iam.serviceAccountUser"
	echo ""
	echo "Project level service account token creator permissions"
	gcloud projects get-iam-policy $PROJECT_ID --format json | jq '.bindings[].role' | grep "roles/iam.serviceAccountTokenCreator"
	echo ""
done;
