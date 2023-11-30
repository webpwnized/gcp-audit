#!/bin/bash

source common-constants.inc;
source functions.inc;

declare ORGANIZATIONAL_IDS=$(gcloud organizations list --format="flattened(ID)" | grep id | cut -d " " -f 2 | cut -d "/" -f 2)

for ORGANIZATION_ID in $ORGANIZATIONAL_IDS; do
	echo "Working on Organizational ID $ORGANIZATION_ID"
	declare FOLDER_IDS=$(gcloud resource-manager folders list --organization $ORGANIZATION_ID)

	for FOLDER_ID in $FOLDER_IDS; do
		echo "Working on Folder $FOLDER_ID"
		echo $BLANK_LINE;
		gcloud resource-manager folders get-iam-policy $FOLDER_ID;
		echo $BLANK_LINE;
		sleep $SLEEP_SECONDS;
	done;
done;
