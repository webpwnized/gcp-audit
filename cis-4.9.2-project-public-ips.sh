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
	declare ADDRESSES=$(gcloud compute addresses list --quiet --format="json");

	if [[ $ADDRESSES != "[]" ]]; then

		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

		echo "---------------------------------------------------------------------------------";
		echo "External IP Addresses for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		echo $ADDRESSES | jq -rc '.[]' | while IFS='' read -r ADDRESS;do
		
			NAME=$(echo $ADDRESS | jq -rc '.name');
			IP_ADDRESS=$(echo $ADDRESS | jq -rc '.address');
			ADDRESS_TYPE=$(echo $ADDRESS | jq -rc '.addressType');
			KIND=$(echo $ADDRESS | jq -rc '.kind');
			STATUS=$(echo $ADDRESS | jq -rc '.status');
			DESCRIPTION=$(echo $ADDRESS | jq -rc '.description');
			VERSION=$(echo $ADDRESS | jq -rc '.ipVersion');
			PURPOSE=$(echo $ADDRESS | jq -rc '.purpose');
			
			if [[ $ADDRESS_TYPE == "EXTERNAL" ]]; then

				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";			

				echo "IP Address: $IP_ADDRESS ($ADDRESS_TYPE $KIND)";
				echo "Name: $NAME";
				if [[ $PURPOSE != "null" ]]; then echo "Purpose: $PURPOSE"; fi;
				if [[ $DESCRIPTION != $NAME && $DESCRIPTION != "" ]]; then echo "Description: $DESCRIPTION"; fi;
				echo "Status: $STATUS";
				if [[ $VERSION != "null" ]]; then echo "Version: $VERSION"; fi;
			else
				echo "Non-issue: The IP address cannot be routed externally";
			fi;
			echo "";
		done;
	else
		echo "No external addresses found for Project $PROJECT_ID";
	fi;
	echo "";
	sleep 0.5;
done;

