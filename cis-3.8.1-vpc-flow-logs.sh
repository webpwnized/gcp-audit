#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);

for PROJECT_ID in $PROJECT_IDS; do

	gcloud config set project $PROJECT_ID;

	declare RESULTS=$(gcloud compute networks list --format json | jq -r '.[].subnetworks | .[]' | xargs -I {} gcloud compute networks subnets describe {} --format json | jq -r '. | "Subnet: \(.name) Purpose: \(.purpose) VPC Flow Log Enabled: \(has("enableFlowLogs"))"');

	if [[ $RESULTS != "" ]]; then
		echo "VPC flow logs for $PROJECT_ID";
		echo $RESULTS;
	else
		echo "No results found for project $PROJECT_ID";
	fi;
	echo "";
	sleep 1;
done;

