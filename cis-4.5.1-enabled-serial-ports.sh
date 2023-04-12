#!/bin/bash

source functions.inc

declare SEPARATOR="---------------------------------------------------------------------------------";
declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare ICH="False";
declare HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-c, --csv] [-i, --include-column-headers] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 			set -- "$@" "-h" ;;
    "--debug") 			set -- "$@" "-d" ;;
    "--csv") 			set -- "$@" "-c" ;;
    "--include-column-headers") set -- "$@" "-i" ;;
    "--project")   		set -- "$@" "-p" ;;
    *)        			set -- "$@" "$arg"
  esac
done

while getopts "hdcip:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_IDS=${OPTARG};;
        d)
        	DEBUG="True";;
        c)
        	CSV="True";;
	i)
		ICH="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;


if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

if [[ $DEBUG == "True" ]]; then
	echo "Projects: $PROJECT_IDS";
fi;

if [[ $ICH == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"INSTANCE_NAME\", \"ENABLED_SERIAL_PORTS\", \"ENABLED_SERIAL_PORTS_STATUS_MESSAGE\"";
fi;

for PROJECT_ID in $PROJECT_IDS; do

	gcloud config set project $PROJECT_ID 2>/dev/null;

	if ! api_enabled compute.googleapis.com; then
		echo "Compute Engine API is not enabled on Project $PROJECT_ID"
		continue
	fi

	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	if [[ $DEBUG == "True" ]]; then
		echo "Instances (JSON): $INSTANCES";
	fi;

	if [[ $CSV != "True" ]]; then
		echo $SEPARATOR;
		echo "Instances for Project $PROJECT_ID";
		echo $SEPARATOR;
	fi;
	
	if [[ $INSTANCES != "[]" ]]; then

		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do

			INSTANCE_NAME=$(echo $INSTANCE | jq -rc '.name');
			ENABLED_SERIAL_PORTS=$(echo $INSTANCE | jq -rc '.metadata.items[] | select(.key=="serial-port-enable")' | jq -rc '.value' | tr '[:upper:]' '[:lower:]' );
			ENABLED_SERIAL_PORTS_STATUS_MESSAGE="Disabled";
			
			if [[ $ENABLED_SERIAL_PORTS != "0" && $ENABLED_SERIAL_PORTS != "" ]]; then
				ENABLED_SERIAL_PORTS_STATUS_MESSAGE="VIOLATION: Serial port enabled";
			fi;
			
			# Print the results gathered above
			if [[ $CSV != "True" ]]; then
				echo "Project ID: $PROJECT_ID";
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";
				echo "Instance Name: $INSTANCE_NAME";
				echo "Serial Port Setting: $ENABLED_SERIAL_PORTS";
				echo "Serial Port Status: $ENABLED_SERIAL_PORTS_STATUS_MESSAGE";
				echo "";
			else
				echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$INSTANCE_NAME\", \"$ENABLED_SERIAL_PORTS\", \"$ENABLED_SERIAL_PORTS_STATUS_MESSAGE\"";
			fi;		

		done;
		echo "";
	else
		if [[ $CSV != "True" ]]; then
			echo "No instances found for project $PROJECT_ID";
			echo "";
		fi;
	fi;
	sleep 0.5;
done;

