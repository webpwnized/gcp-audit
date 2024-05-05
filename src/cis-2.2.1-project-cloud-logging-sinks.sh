#!/bin/bash

source common-constants.inc;
source functions.inc;

declare SEPARATOR="---------------------------------------------------------------------------------";
declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-c, --csv] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 			set -- "$@" "-h" ;;
    "--debug") 			set -- "$@" "-d" ;;
    "--csv") 			set -- "$@" "-c" ;;
    "--project")   		set -- "$@" "-p" ;;
    *)        			set -- "$@" "$arg"
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

declare DEFAULT_DEFAULT_LOG_SINK_FILTER="NOT LOG_ID(\"cloudaudit.googleapis.com/activity\") AND NOT LOG_ID(\"externalaudit.googleapis.com/activity\") AND NOT LOG_ID(\"cloudaudit.googleapis.com/system_event\") AND NOT LOG_ID(\"externalaudit.googleapis.com/system_event\") AND NOT LOG_ID(\"cloudaudit.googleapis.com/access_transparency\") AND NOT LOG_ID(\"externalaudit.googleapis.com/access_transparency\")";

declare DEFAULT_REQUIRED_LOG_SINK_FILTER="LOG_ID(\"cloudaudit.googleapis.com/activity\") OR LOG_ID(\"externalaudit.googleapis.com/activity\") OR LOG_ID(\"cloudaudit.googleapis.com/system_event\") OR LOG_ID(\"externalaudit.googleapis.com/system_event\") OR LOG_ID(\"cloudaudit.googleapis.com/access_transparency\") OR LOG_ID(\"externalaudit.googleapis.com/access_transparency\")";

declare SINK_FILTER_IS_DEFAULT_DEFAULT_MESSAGE="NOTICE: Google _Default log sink filter is in use";

declare SINK_FILTER_IS_REQUIRED_DEFAULT_MESSAGE="NOTICE: Google _Required log sink filter is in use";

declare SINK_FILTER_IS_NOT_DEFAULT_MESSAGE="NOTICE: Custom log sink filter is in use";

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

if [[ $DEBUG == "True" ]]; then
	echo "Projects: $PROJECT_IDS";
	echo $BLANK_LINE;
fi;

if [[ $CSV == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"SINK_NAME\", \"SINK_DESTINATION\", \"SINK_FILTER_IS_DEFAULT_DEFAULT\", \"SINK_FILTER_IS_REQUIRED_DEFAULT\", \"SINK_FILTER_MESSAGE\", \"SINK_FILTER\"";	
fi;

for PROJECT_ID in $PROJECT_IDS; do

	set_project $PROJECT_ID;

	if ! api_enabled logging.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "WARNING: Logging API is not enabled";
		fi;
		continue;
	fi;

	declare SINKS=$(gcloud logging sinks list --format json --project="$PROJECT_ID");
	
	if [[ $DEBUG == "True" ]]; then
		echo "Sinks (JSON): $SINKS";
		echo $BLANK_LINE;
	fi;
	
	if [[ $CSV != "True" ]]; then
		echo $SEPARATOR;
		echo "Log Sinks for Project $PROJECT_ID";
		echo $SEPARATOR;
	fi;
	
	if [[ $SINKS != "[]" ]]; then

      		#Get project details
      		get_project_details $PROJECT_ID
	
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
				echo "Project ID: $PROJECT_ID";
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";
				echo "Log Sink Name: $SINK_NAME";
				echo "Log Sink Destination: $SINK_DESTINATION";
				echo "Log Sink Filter Message: $SINK_FILTER_MESSAGE";
				echo "Log Sink Filter: $SINK_FILTER";
				echo $BLANK_LINE;
			else
				echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$SINK_NAME\", \"$SINK_DESTINATION\", \"$SINK_FILTER_IS_DEFAULT_DEFAULT\", \"$SINK_FILTER_IS_REQUIRED_DEFAULT\", \"$SINK_FILTER_MESSAGE\", \"$SINK_FILTER\"";
			fi;		

		done;

	else
		if [[ $CSV != "True" ]]; then
			echo "No log sinks found for project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
	fi;
	sleep $SLEEP_SECONDS;
done;

