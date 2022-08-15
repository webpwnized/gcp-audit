#!/bin/bash

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

