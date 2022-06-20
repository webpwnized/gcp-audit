#!/bin/bash

declare ORGANIZATION_IDS=$(gcloud organizations list --format="flattened(ID)" | grep id | cut -d " " -f 2 | cut -d "/" -f 2)

for ORGANIZATION_ID in $ORGANIZATION_IDS; do
	echo "Organization Policy for Organization $ORGANIZATION_IDS"
	echo ""
	gcloud resource-manager org-policies list --organization=$ORGANIZATION_ID | grep "SET";
	echo ""
done;
