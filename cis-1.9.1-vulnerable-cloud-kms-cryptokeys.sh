#!/bin/bash

if [[ $(gcloud services list --enabled | grep -c cloudkms) == 0 ]]; then
	echo "Cloud KMS not enabled.";
	exit 1;
fi;

declare LOCATIONS=$(gcloud kms locations list --format="flattened(locationId)" | grep location_id | cut -d " " -f2)

for LOCATION in $LOCATIONS; do
	echo "Keyrings for Location $LOCATION"
	echo ""
	
	declare KEYRINGS=$(gcloud kms keyrings list --location=$LOCATION --format="flattened()" | grep key_id | cut -d " " -f 2)

	for KEYRING in $KEYRINGS; do
		echo "Keys for Keyring $KEYRING"
		echo ""
		declare KEYS=$(gcloud kms keys list --keyring=$KEYRING --location=$LOCATION --format=json | jq '.[].name' --format="flattened()" | grep key_id | cut -d " " -f 2);
		echo ""
		for KEY in $KEYS; do
			echo "Policy for Key $KEY"
			echo ""
			gcloud kms keys get-iam-policy $KEY --keyring=$KEYRING -- location=$LOCATION --format=json | jq '.bindings[].members[]';
			echo ""
		done;
		echo ""
	done;
	echo ""
done;
