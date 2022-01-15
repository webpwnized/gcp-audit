#!/bin/bash

declare ORGANIZATION_IDS=$(gcloud organizations list --format="flattened(ID)" | grep id | cut -d " " -f 2 | cut -d "/" -f 2)

for ORGANIZATION_ID in $ORGANIZATION_IDS; do
	echo "IAM Policy for Project $ORGANIZATION_IDS"
	echo ""
	gcloud organizations get-iam-policy $ORGANIZATION_ID;
	echo ""
done;
