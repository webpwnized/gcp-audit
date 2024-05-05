#!/bin/bash

source common-constants.inc;
source functions.inc;

if ! api_enabled cloudkms.googleapis.com; then
	echo "Cloud KMS not enabled.";
	exit 1;
fi

declare LOCATIONS=$(gcloud kms locations list --format="flattened(locationId)" | grep location_id | cut -d " " -f2)

for LOCATION in $LOCATIONS; do
	echo "Keyrings for Location $LOCATION"
	echo $BLANK_LINE;
	
	declare KEYRINGS=$(gcloud kms keyrings list --location=$LOCATION --format="flattened()" | grep key_id | cut -d " " -f 2)

	for KEYRING in $KEYRINGS; do
		echo "Keys for Keyring $KEYRING"
		echo $BLANK_LINE;
		declare KEYS=$(gcloud kms keys list --keyring=$KEYRING --location=$LOCATION --format=json | jq '.[].name' --format="flattened()" | grep key_id | cut -d " " -f 2);
		echo $BLANK_LINE;
		for KEY in $KEYS; do
			echo "Policy for Key $KEY"
			echo $BLANK_LINE;
			gcloud kms keys get-iam-policy $KEY --keyring=$KEYRING -- location=$LOCATION --format=json | jq '.bindings[].members[]';
			echo $BLANK_LINE;
		done;
		echo $BLANK_LINE;
	done;
	echo $BLANK_LINE;
	sleep $SLEEP_SECONDS;
done;
