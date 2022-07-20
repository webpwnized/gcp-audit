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
	declare SERVICES=$(gcloud run services list --quiet --format="json");

	if [[ $SERVICES != "[]" ]]; then
	
		echo "---------------------------------------------------------------------------------";
		echo "Cloud Run Services for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		echo $SERVICES | jq -rc '.[]' | while IFS='' read -r SERVICE;do
		
			NAME=$(echo $SERVICE | jq -rc '.metadata.name');
			INGRESS_SETTING=$(echo $SERVICE | jq -rc '.metadata.annotations."run.googleapis.com/ingress"');
			
			echo "Service Name: $NAME";
			echo "Service Ingress Setting: $INGRESS_SETTING";
						
			if [[ $INGRESS_SETTING == "all" ]]; then
				echo "Violation: The ingress setting is configured to ALL, which allows all requests including requests directly from the internet";
			fi;
			echo "";
		done;
		echo "";
	else
		echo "No Cloud Run Services found for Project $PROJECT_ID";
		echo "";
	fi;
	sleep 0.5;
done;

