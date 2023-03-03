#!/bin/bash

source helpers.inc

declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
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

if ! api_enabled logging.googleapis.com; then
	echo "WARNING: Logging API is not enabled";
	exit 1000;
fi;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

for PROJECT_ID in $PROJECT_IDS; do

	declare SINKS=$(gcloud logging sinks list --format json --project="$PROJECT_ID");
	
	if [[ $DEBUG == "True" ]]; then
		echo "Sinks (JSON): $SINKS";
	fi;
	
	if [[ $CSV != "True" ]]; then
		echo "---------------------------------------------------------------------------------";
		echo "Log Sinks for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";
	fi;
	
	if [[ $SINKS != "[]" ]]; then

		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');
	
		echo $SINKS | jq -rc '.[]' | while IFS='' read -r SINK;do
		
			if [[ $DEBUG == "True" ]]; then
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";			
				echo "Log Sink (JSON): $SINK";
			fi;

			SINK_NAME=$(echo $SINK | jq -rc '.name');
			SINK_DESTINATION=$(echo $SINK | jq -rc '.destination');
			SINK_FILTER=$(echo $SINK | jq -rc '.filter');

			# Print the results gathered above
			if [[ $CSV != "True" ]]; then
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";			
				echo "Log Sink Name: $SINK_NAME";
				echo "Log Sink Destination: $SINK_DESTINATION";
				echo "Log Sink Filter: $SINK_FILTER";
				echo "";
			else
				echo "$PROJECT_ID, \"$PROJECT_NAME\", $PROJECT_OWNER, $PROJECT_APPLICATION, $SINK_NAME, $SINK_DESTINATION, \"$SINK_FILTER\"";
			fi;		

		done;

	else
		if [[ $CSV != "True" ]]; then
			echo "No log sinks found for project $PROJECT_ID";
			echo "";
		fi;
	fi;
	sleep 0.5;
done;

