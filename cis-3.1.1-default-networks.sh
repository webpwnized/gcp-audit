#!/bin/bash

source common-constants.inc;
source functions.inc;

PROJECT_IDS="";
DEBUG="False";
HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 		set -- "$@" "-h" ;;
    "--debug") 		set -- "$@" "-d" ;;
    "--project")   	set -- "$@" "-p" ;;
    *)        		set -- "$@" "$arg"
  esac
done

while getopts "hdp:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_IDS=${OPTARG};;
        d)
        	DEBUG="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;


if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

for PROJECT_ID in $PROJECT_IDS; do
	set_project $PROJECT_ID;

	if ! api_enabled compute.googleapis.com; then
		echo "Compute Engine API is not enabled on Project $PROJECT_ID"
		continue;
	fi
	
	declare RESULTS=$(gcloud compute networks list --quiet --format="json" | tr [:upper:] [:lower:] | jq '.[]');
	
	declare SUBNET_MODE="";
	if [[ $RESULTS != "[]" ]]; then
		NETWORK_NAME=$(echo $RESULTS | jq '.name');
		SUBNET_MODE=$(echo $RESULTS | jq '.x_gcloud_subnet_mode');
	fi;
	
	if [[ $NETWORK_NAME == "default" ]]; then
		echo "VIOLATION: Default network $NETWORK_NAME detected for Project $PROJECT_ID";
		echo $BLANK_LINE;
	elif [[ $SUBNET_MODE == "legacy" ]]; then
		echo "VIOLATION: Legacy network $NETWORK_NAME detected for Project $PROJECT_ID";
		echo $BLANK_LINE;
	fi;
	sleep $SLEEP_SECONDS;
done;
