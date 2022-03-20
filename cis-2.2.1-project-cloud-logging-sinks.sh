#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)

for PROJECT_ID in $PROJECT_IDS; do
	echo "IAM Policy for Project $PROJECT_ID"
	echo ""
	gcloud logging sinks list --project=$PROJECT_ID;
	echo ""
done;
