#!/bin/bash

source common-constants.inc;

if [[ $(gcloud services list --enabled | grep -c cloudkms) == 0 ]]; then
	echo "Cloud KMS not enabled.";
	exit 1;
fi;

declare LOCATIONS=$(gcloud kms locations list --format="flattened(locationId)" | grep location_id | cut -d " " -f2)

for LOCATION in $LOCATIONS; do
	echo "Keysrings for Location $LOCATION"
	echo $BLANK_LINE;
	
	declare KEYRINGS=$(gcloud kms keyrings list --location="$LOCATION" --format="flattened()" | grep key_id | cut -d " " -f 2)

	for KEYRING in $KEYRINGS; do
		echo "Key rotation periods for Keyring $KEYRING"
		echo $BLANK_LINE;
		declare KEYS=$(gcloud kms keys list --keyring="$KEYRING" --location="$LOCATION" --format=json'(rotationPeriod)');
		echo $BLANK_LINE;
	done;
	echo $BLANK_LINE;
	sleep $SLEEP_SECONDS; 
done;
