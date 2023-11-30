#!/bin/bash

source common-constants.inc;
source functions.inc;

declare ORGANIZATION_IDS=$(gcloud organizations list --format="flattened(ID)" | grep id | cut -d " " -f 2 | cut -d "/" -f 2)

for ORGANIZATION_ID in $ORGANIZATION_IDS; do
	if ! api_enabled essentialcontacts.googleapis.com; then
		echo "Essential Contacts API is not enabled for Organization $ORGANIZATION_ID"
		continue;
	fi

	echo "Essential Contacts for Organization $ORGANIZATION_IDS";
	echo $BLANK_LINE;
	gcloud essential-contacts list --organization=$ORGANIZATION_ID;
	echo $BLANK_LINE;
	sleep $SLEEP_SECONDS;
done;
