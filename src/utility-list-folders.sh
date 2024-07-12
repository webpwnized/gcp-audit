#!/bin/bash

source common-constants.inc;

ORGANIZATION_IDS=$(gcloud organizations list --format="flattened(ID)" | grep id | cut -d " " -f 2 | cut -d "/" -f 2);

for ORGANIZATION_ID in $ORGANIZATION_IDS; do
	gcloud resource-manager folders list --organization $ORGANIZATION_ID
	echo $BLANK_LINE;
	sleep $SLEEP_SECONDS;
done;
