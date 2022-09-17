#!/bin/bash

source helpers.inc

PROJECT_IDS="";
DEBUG="False";
CSV="False";
HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [--csv] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 		set -- "$@" "-h" ;;
    "--debug") 		set -- "$@" "-d" ;;
    "--csv") 		set -- "$@" "-c" ;;
    "--project")   	set -- "$@" "-p" ;;
    *)        		set -- "$@" "$arg"
  esac
done

while getopts "hdcp:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_IDS=${OPTARG};;
        d)
        	DEBUG="True";;
        c)
        	CSV="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(gcloud projects list --quiet --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

for PROJECT_ID in $PROJECT_IDS; do
	gcloud config set project $PROJECT_ID 2>/dev/null;
	sleep 0.5;
	
	if ! api_enabled compute.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "Compute Engine API is not enabled for Project $PROJECT_ID.";
		fi;
		continue;
	fi;
	
	declare ADDRESSES=$(gcloud compute addresses list --quiet --format="json");

	if [[ $ADDRESSES != "[]" ]]; then

		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

		if [[ $CSV != "True" ]]; then
			echo "---------------------------------------------------------------------------------";
			echo "External IP Addresses for Project $PROJECT_ID";
			echo "---------------------------------------------------------------------------------";
		fi;
		
		echo $ADDRESSES | jq -rc '.[]' | while IFS='' read -r ADDRESS;do
		
			if [[ $DEBUG == "True" ]]; then
				echo $ADDRESS | jq -rc '.';
			fi;

			NAME=$(echo $ADDRESS | jq -rc '.name');
			IP_ADDRESS=$(echo $ADDRESS | jq -rc '.address');
			ADDRESS_TYPE=$(echo $ADDRESS | jq -rc '.addressType');
			KIND=$(echo $ADDRESS | jq -rc '.kind');
			STATUS=$(echo $ADDRESS | jq -rc '.status');
			DESCRIPTION=$(echo $ADDRESS | jq -rc '.description');
			VERSION=$(echo $ADDRESS | jq -rc '.ipVersion');
			PURPOSE=$(echo $ADDRESS | jq -rc '.purpose');
			
			if [[ $PURPOSE == "NAT_AUTO" ]]; then
				if [[ $CSV != "True" ]]; then
					echo "Non-issue: The IP address belong to a Cloud NAT Router";
					echo "";
				fi;
			elif [[ $ADDRESS_TYPE == "EXTERNAL" ]]; then

				if [[ $CSV != "True" ]]; then
					echo "Project Name: $PROJECT_NAME";
					echo "Project Application: $PROJECT_APPLICATION";
					echo "Project Owner: $PROJECT_OWNER";			

					echo "IP Address: $IP_ADDRESS ($ADDRESS_TYPE $KIND)";
					echo "Name: $NAME";
					if [[ $PURPOSE != "null" ]]; then echo "Purpose: $PURPOSE"; fi;
					if [[ $DESCRIPTION != $NAME && $DESCRIPTION != "" ]]; then echo "Description: $DESCRIPTION"; fi;
					echo "Status: $STATUS";
					if [[ $VERSION != "null" ]]; then echo "Version: $VERSION"; fi;
					echo "";
				else
					echo "$PROJECT_NAME, $PROJECT_APPLICATION, $PROJECT_OWNER, $IP_ADDRESS, $ADDRESS_TYPE, $KIND, $NAME, $PURPOSE, \"$DESCRIPTION\", $STATUS, $VERSION";
				fi;
			else
				if [[ $CSV != "True" ]]; then
					echo "Non-issue: The IP address cannot be routed externally";
					echo "";
				fi;
			fi;
		done;
	else
		if [[ $CSV != "True" ]]; then
			echo "No external addresses found for Project $PROJECT_ID";
			echo "";
		fi;
	fi;
	sleep 0.5;
done;

