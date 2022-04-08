#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2)

for PROJECT_ID in $PROJECT_IDS; do	
	gcloud config set project $PROJECT_ID;
	declare ADDRESSES=$(gcloud compute addresses list --quiet --format="json");

	if [[ $ADDRESSES != "[]" ]]; then
	
		echo "---------------------------------------------------------------------------------";
		echo "Addresses for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		echo $ADDRESSES | jq -rc '.[]' | while IFS='' read -r ADDRESS;do
		
			NAME=$(echo $ADDRESS | jq -rc '.name');
			IP_ADDRESS=$(echo $ADDRESS | jq -rc '.address');
			ADDRESS_TYPE=$(echo $ADDRESS | jq -rc '.addressType');
			KIND=$(echo $ADDRESS | jq -rc '.kind');
			STATUS=$(echo $ADDRESS | jq -rc '.status');
			DESCRIPTION=$(echo $ADDRESS | jq -rc '.description');
			VERSION=$(echo $ADDRESS | jq -rc '.ipVersion');

			if [[ $ADDRESS_TYPE == "EXTERNAL" ]]; then
				echo "IP Address: $IP_ADDRESS ($ADDRESS_TYPE $KIND)";
				echo "Name: $NAME";
				if [[ $DESCRIPTION != $NAME && $DESCRIPTION != "" ]]; then echo "Description: $DESCRIPTION"; fi;
				echo "Status: $STATUS";
				if [[ $VERSION != "null" ]]; then echo "Version: $VERSION"; fi;
				echo "";
			fi;
		done;
		echo "";
	else
		echo "No external addresses found for Project $PROJECT_ID";
		echo "";
	fi;
	sleep 1;
done;

