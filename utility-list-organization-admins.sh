#!/bin/bash

declare ORGANIZATION_IDS=$(gcloud organizations list --format="flattened(ID)" | grep id | cut -d " " -f 2 | cut -d "/" -f 2)

for ORGANIZATION_ID in $ORGANIZATION_IDS; do
	echo "Organization Admins for $ORGANIZATION_IDS"
	echo ""
	gcloud organizations get-iam-policy $ORGANIZATION_ID | grep -B 1 'roles/resourcemanager.organizationAdmin' | grep 'user' | cut -d : -f2;
	echo ""
done;
