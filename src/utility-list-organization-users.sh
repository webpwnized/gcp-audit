#!/bin/bash

source common-constants.inc;

declare ORGANIZATION_IDS=$(gcloud organizations list --format="flattened(ID)" | grep id | cut -d " " -f 2 | cut -d "/" -f 2)

for ORGANIZATION_ID in $ORGANIZATION_IDS; do
	echo "IAM Policy for Organization $ORGANIZATION_IDS"
	echo $BLANK_LINE;
	gcloud organizations get-iam-policy $ORGANIZATION_ID | grep user: | cut -d ":" -f 2 |sort -u;
	echo $BLANK_LINE;
	sleep $SLEEP_SECONDS;
done;
