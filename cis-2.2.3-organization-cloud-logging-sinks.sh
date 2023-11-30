#!/bin/bash

source common-constants.inc;
source functions.inc;

declare ORGANIZATION_IDS="";
declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
	$0 [-o, --organization ORGANIZATION] [-c, --csv] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 			set -- "$@" "-h" ;;
    "--debug") 			set -- "$@" "-d" ;;
    "--csv") 			set -- "$@" "-c" ;;
    "--orgnanization")   	set -- "$@" "-o" ;;
    *)        			set -- "$@" "$arg"
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

declare DEFAULT_DEFAULT_LOG_SINK_FILTER="NOT LOG_ID(\"cloudaudit.googleapis.com/activity\") AND NOT LOG_ID(\"externalaudit.googleapis.com/activity\") AND NOT LOG_ID(\"cloudaudit.googleapis.com/system_event\") AND NOT LOG_ID(\"externalaudit.googleapis.com/system_event\") AND NOT LOG_ID(\"cloudaudit.googleapis.com/access_transparency\") AND NOT LOG_ID(\"externalaudit.googleapis.com/access_transparency\")";

declare DEFAULT_REQUIRED_LOG_SINK_FILTER="LOG_ID(\"cloudaudit.googleapis.com/activity\") OR LOG_ID(\"externalaudit.googleapis.com/activity\") OR LOG_ID(\"cloudaudit.googleapis.com/system_event\") OR LOG_ID(\"externalaudit.googleapis.com/system_event\") OR LOG_ID(\"cloudaudit.googleapis.com/access_transparency\") OR LOG_ID(\"externalaudit.googleapis.com/access_transparency\")";

declare SINK_FILTER_IS_DEFAULT_DEFAULT_MESSAGE="NOTICE: Google _Default log sink filter is in use";

declare SINK_FILTER_IS_REQUIRED_DEFAULT_MESSAGE="NOTICE: Google _Required log sink filter is in use";

declare SINK_FILTER_IS_NOT_DEFAULT_MESSAGE="NOTICE: Custom log sink filter is in use";

if [[ $ORGANIZATIONAL_IDS == "" ]]; then
    declare ORGANIZATIONS=$(gcloud organizations list --format="json");
fi;

if [[ $DEBUG == "True" ]]; then
	echo "Organizations (JSON): $ORGANIZATIONS";
fi;

if [[ $CSV == "True" ]]; then
	echo "\"ORGANIZATION_DISPLAY_NAME\", \"SINK_NAME\", \"SINK_DESTINATION\", \"SINK_FILTER_IS_DEFAULT_DEFAULT\", \"SINK_FILTER_IS_REQUIRED_DEFAULT\", \"SINK_FILTER_MESSAGE\", \"SINK_FILTER\"";
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
		echo $BLANK_LINE;
	fi;

	if [[ $SINKS != "[]" ]]; then
		
		echo $SINKS | jq -rc '.[]' | while IFS='' read -r SINK;do
			
			if [[ $DEBUG == "True" ]]; then
				echo "Log Sink (JSON): $SINK";
			fi;

			SINK_NAME=$(echo $SINK | jq -rc '.name');
			SINK_DESTINATION=$(echo $SINK | jq -rc '.destination');
			SINK_FILTER=$(echo $SINK | jq -rc '.filter');
			SINK_FILTER_IS_DEFAULT_DEFAULT="False";
			SINK_FILTER_IS_REQUIRED_DEFAULT="False";
			
			if [[ $SINK_FILTER == $DEFAULT_DEFAULT_LOG_SINK_FILTER ]]; then
				SINK_FILTER_IS_DEFAULT_DEFAULT="True";
				SINK_FILTER_MESSAGE=$SINK_FILTER_IS_DEFAULT_DEFAULT_MESSAGE;
			elif [[ $SINK_FILTER == $DEFAULT_REQUIRED_LOG_SINK_FILTER ]]; then
				SINK_FILTER_IS_REQUIRED_DEFAULT="True";
				SINK_FILTER_MESSAGE=$SINK_FILTER_IS_REQUIRED_DEFAULT_MESSAGE;			
			else
				SINK_FILTER_MESSAGE=$SINK_FILTER_IS_NOT_DEFAULT_MESSAGE;
			fi;

			# Print the results gathered above
			if [[ $CSV != "True" ]]; then
				echo "Organization: $ORGANIZATION_DISPLAY_NAME";
				echo "Log Sink Name: $SINK_NAME";
				echo "Log Sink Destination: $SINK_DESTINATION";
				echo "Log Sink Filter Message: $SINK_FILTER_MESSAGE";
				echo "Log Sink Filter: $SINK_FILTER";
				echo $BLANK_LINE;
			else
				echo "\"$ORGANIZATION_DISPLAY_NAME\", \"$SINK_NAME\", \"$SINK_DESTINATION\", \"$SINK_FILTER_IS_DEFAULT_DEFAULT\", \"$SINK_FILTER_IS_REQUIRED_DEFAULT\", \"$SINK_FILTER_MESSAGE\", \"$SINK_FILTER\"";
			fi; # if csv	

		done; #sinks
	else
		if [[ $CSV != "True" ]]; then
			echo "No log sinks found for organization $ORGANIZATION_DISPLAY_NAME";
			echo $BLANK_LINE;
		fi;
	fi;
	sleep $SLEEP_SECONDS;
done; #organizations

