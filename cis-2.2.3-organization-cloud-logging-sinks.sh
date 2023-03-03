#!/bin/bash

source helpers.inc

declare ORGANIZATION_IDS="";
declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
	$0 [-o, --organization ORGANIZATION] [--csv] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 		set -- "$@" "-h" ;;
    "--debug") 		set -- "$@" "-d" ;;
    "--csv") 		set -- "$@" "-c" ;;
    "--orgnanization")   	set -- "$@" "-o" ;;
    *)        		set -- "$@" "$arg"
  esac
done

while getopts "hdco:" option
do 
    case "${option}"
        in
        o)
        	ORGNAIZATION_IDS=${OPTARG};;
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

if [[ $ORGANIZATIONAL_IDS == "" ]]; then
    declare ORGANIZATIONS=$(gcloud organizations list --format="json");
fi;

if [[ $DEBUG == "True" ]]; then
	echo "Organizations (JSON): $ORGANIZATIONS";
fi;

echo $ORGANIZATIONS | jq -rc '.[]' | while IFS='' read -r ORGANIZATION; do

	ORGANIZATION_NAME=$(echo $ORGANIZATION | jq -rc '.name' | cut -d"/" -f2);
	ORGANIZATION_DISPLAY_NAME=$(echo $ORGANIZATION | jq -rc '.displayName');
	
	declare SINKS=$(gcloud logging sinks list --format="json" --organization="$ORGANIZATION_NAME");

	if [[ $DEBUG == "True" ]]; then
		echo "Sinks (JSON): $SINKS";
	fi;
		
	if [[ $CSV != "True" ]]; then
		echo "---------------------------------------------------------------------------------";
		echo "Log Sinks for Organization $ORGANIZATION_DISPLAY_NAME";
		echo "---------------------------------------------------------------------------------";
		echo "";
	fi;

	if [[ $SINKS != "[]" ]]; then
		
		echo $SINKS | jq -rc '.[]' | while IFS='' read -r SINK;do
			
			if [[ $DEBUG == "True" ]]; then
				echo "Log Sink (JSON): $SINK";
			fi;

			SINK_NAME=$(echo $SINK | jq -rc '.name');
			SINK_DESTINATION=$(echo $SINK | jq -rc '.destination');
			SINK_FILTER=$(echo $SINK | jq -rc '.filter');

			# Print the results gathered above
			if [[ $CSV != "True" ]]; then
				echo "Organization: $ORGANIZATION_DISPLAY_NAME";
				echo "Log Sink Name: $SINK_NAME";
				echo "Log Sink Destination: $SINK_DESTINATION";
				echo "Log Sink Filter: $SINK_FILTER";
				echo "";
			else
				echo "$ORGANIZATION_DISPLAY_NAME, $SINK_NAME, $SINK_DESTINATION, \"$SINK_FILTER\"";
			fi; # if csv	

			done; #sinks
	else
		if [[ $CSV != "True" ]]; then
			echo "No log sinks found for organization $ORGANIZATION_DISPLAY_NAME";
			echo "";
		fi;
	fi;
	sleep 0.5;
done; #organizations

