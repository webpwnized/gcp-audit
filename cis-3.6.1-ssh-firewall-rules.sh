#!/bin/bash

declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);

for PROJECT_ID in $PROJECT_IDS; do

	gcloud config set project $PROJECT_ID;

	declare RESULTS=$(gcloud compute firewall-rules list --format="json");

	if [[ $RESULTS != "[]" ]]; then
		
		echo "Firewall rules for $PROJECT_ID";
		echo "";
		
		echo $RESULTS | jq -rc '.[]' | while IFS='' read FIREWALL_RULE;do
		
			NAME=$(echo $FIREWALL_RULE | jq '.name');
			ALLOWED=$(echo $FIREWALL_RULE | jq -c '.allowed');
			DENIED=$(echo $FIREWALL_RULE | jq -c '.denied');
			DIRECTION=$(echo $FIREWALL_RULE | jq '.direction');
			LOG_CONFIG=$(echo $FIREWALL_RULE | jq '.logConfig.enable');
			SOURCE_RANGES=$(echo $FIREWALL_RULE | jq -c '.sourceRanges');
			SOURCE_TAGS=$(echo $FIREWALL_RULE | jq -c '.sourceTags');
			DEST_RANGES=$(echo $FIREWALL_RULE | jq -c '.destinationRanges');
			DEST_TAGS=$(echo $FIREWALL_RULE | jq -c '.sourceTags');
			DISABLED=$(echo $FIREWALL_RULE | jq '.disabled');
			
			echo "Name: $NAME ($DIRECTION)";
			if [[ $ALLOWED != "null" ]]; then echo "Allowed: $ALLOWED"; fi;
			if [[ $DENIED != "null" ]]; then echo "Denied: $DENIED"; fi;
			if [[ $SOURCE_RANGES != "null" ]]; then echo "Source Ranges: $SOURCE_RANGES"; fi;
			if [[ $SOURCE_TAGS != "null" ]]; then echo "Source Tags: $SOURCE_TAGS"; fi;
			if [[ $DEST_RANGES != "null" ]]; then echo "Destination Ranges: $DEST_RANGES"; fi;
			if [[ $DEST_TAGS != "null" ]]; then echo "Destination Tags: $DEST_TAGS"; fi;
			if [[ $LOG_CONFIG != "null" ]]; then echo "Logging: $LOG_CONFIG"; fi;
			if [[ $DISABLED != "null" ]]; then echo "Disabled: $DISABLED"; fi;
			
			echo "";
		done;
	else
		echo "No firewall rules found for $PROJECT_ID";
		echo "";
	fi;
	sleep 1;
done;

