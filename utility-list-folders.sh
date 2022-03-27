#!/bin/bash

ORGANIZATION_IDS=$(gcloud organizations list --format="flattened(ID)" | grep id | cut -d " " -f 2 | cut -d "/" -f 2);

for ORGANIZATION_ID in $ORGANIZATION_IDS; do
	gcloud resource-manager folders list --organization $ORGANIZATION_ID
	echo "";
	sleep 1;
done;
