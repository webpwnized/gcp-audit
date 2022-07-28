#!/bin/bash

LONG=project:
SHORT=p:
OPTS=$(getopt -a -n testscript --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"
while :
do
    case "$1" in --project | -p )
        declare PROJECT_IDS="$2"
        shift 2
     ;;
     -- )
        shift;
        break
        ;;
        *)
        exit 2
    esac
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

for PROJECT_ID in $PROJECT_IDS; do
	gcloud config set project $PROJECT_ID;
	declare RESULTS=$(gcloud compute networks list --quiet --format="json" | tr [:upper:] [:lower:] | jq '.[]');
	
	declare SUBNET_MODE="";
	if [[ $RESULTS != "[]" ]]; then
		NETWORK_NAME=$(echo $RESULTS | jq '.name');
		SUBNET_MODE=$(echo $RESULTS | jq '.x_gcloud_subnet_mode');
	fi;
	
	if [[ $NETWORK_NAME == "default" ]]; then
		echo "VIOLATION: Default network $NETWORK_NAME detected for Project $PROJECT_ID";
		echo "";
	elif [[ $SUBNET_MODE == "legacy" ]]; then
		echo "VIOLATION: Legacy network $NETWORK_NAME detected for Project $PROJECT_ID";
		echo "";
	fi
done;
