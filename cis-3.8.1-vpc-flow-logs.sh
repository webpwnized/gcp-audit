#!/bin/bash

source common-constants.inc;
source functions.inc;

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

while getopts "hdcp:r:" option
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
    declare PROJECT_IDS=$(get_projects);
fi;

if [[ $CSV == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"SUBNET_NAME\", \"IP_RANGE\", \"FLOW_LOGS_ENABLED\", \"FLOW_LOG_AGGREGATION_INTERVAL\", \"FLOW_LOG_SAMPLE_RATE\", \"FLOW_LOG_METADATA_CONFIGURATION\", \"FLOW_LOGS_ENABLED\", \"FLOW_LOG_STATUS_MESSAGE\", \"FLOW_LOG_SAMPLE_RATE_STATUS_MESSAGE\"";
fi;

for PROJECT_ID in $PROJECT_IDS; do

	set_project $PROJECT_ID;

	if ! api_enabled compute.googleapis.com ; then
		echo "Compute Engine API is not enabled on Project $PROJECT_ID";
		continue;
	fi;

	declare SUBNETS=$(gcloud compute networks subnets list --format json);
	
	if [[ $CSV != "True" ]]; then
		echo "---------------------------------------------------------------------------------";
		echo "Subnets for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";
	fi;
	
	if [[ $SUBNETS != "[]" ]]; then

      		#Get project details
      		get_project_details $PROJECT_ID

		echo $SUBNETS | jq -rc '.[]' | while IFS='' read -r SUBNET;do
			
			SUBNET_NAME=$(echo $SUBNET | jq -rc '.name');
			IP_RANGE=$(echo $SUBNET | jq -rc '.ipCidrRange');
			FLOW_LOGS_CONFIGURED=$(echo $SUBNET | jq -rc '.logConfig // ""');
			
			if [[ $FLOW_LOGS_CONFIGURED != "" ]]; then
			
				FLOW_LOGS_ENABLED=$(echo $SUBNET | jq -rc '.enableFlowLogs');
				FLOW_LOG_AGGREGATION_INTERVAL=$(echo $SUBNET | jq -rc '.logConfig.aggregationInterval');
				FLOW_LOG_SAMPLE_RATE=$(echo $SUBNET | jq -rc '.logConfig.flowSampling');
				FLOW_LOG_METADATA_CONFIGURATION=$(echo $SUBNET | jq -rc '.logConfig.metadata');
				
				# Returns 0 for FALSE and 1 for TRUE
				FLOW_LOG_SAMPLE_RATE_TOO_LOW=$(echo "$FLOW_LOG_SAMPLE_RATE < 0.10" | bc);

				if [[ $FLOW_LOGS_ENABLED == "false" ]]; then
					FLOW_LOG_STATUS_MESSAGE="VIOLATION: Flow logging is configured but not enabled";
				else
					FLOW_LOG_STATUS_MESSAGE="PASS: Flow log enabled";
				fi;

				if [[ $FLOW_LOG_SAMPLE_RATE_TOO_LOW == 1 ]]; then
					FLOW_LOG_SAMPLE_RATE_STATUS_MESSAGE="VIOLATION: Flow log sample rate is too low";
				else
					FLOW_LOG_SAMPLE_RATE_STATUS_MESSAGE="PASS: Flow log sample rate is at least 10%";
				fi;
					
			else # $FLOW_LOGS_CONFIGURED is NULL
				FLOW_LOGS_ENABLED="false";
				FLOW_LOG_AGGREGATION_INTERVAL="0";
				FLOW_LOG_SAMPLE_RATE="0";
				FLOW_LOG_METADATA_CONFIGURATION="false";
				FLOW_LOG_STATUS_MESSAGE="VIOLATION: Flow logging is configured but not enabled";
				FLOW_LOG_SAMPLE_RATE_STATUS_MESSAGE="VIOLATION: Flow log sample rate is too low";
			fi;

			# Print the results gathered above
			if [[ $CSV != "True" ]]; then
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";			
				echo "Subnet: $SUBNET_NAME";
				echo "IP Range: $IP_RANGE";
				echo "Flow Log Enabled: $FLOW_LOGS_ENABLED";
				echo "Flow Log Aggregation Interval: $FLOW_LOG_AGGREGATION_INTERVAL";
				echo "Flow Log Sample Rate: $FLOW_LOG_SAMPLE_RATE";
				echo "Flow Log Metadata Configuration: $FLOW_LOG_METADATA_CONFIGURATION";
				echo $FLOW_LOG_STATUS_MESSAGE;
				echo $FLOW_LOG_SAMPLE_RATE_STATUS_MESSAGE;
				echo $BLANK_LINE;
			else
				echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$SUBNET_NAME\", \"$IP_RANGE\", \"$FLOW_LOGS_ENABLED\", \"$FLOW_LOG_AGGREGATION_INTERVAL\", \"$FLOW_LOG_SAMPLE_RATE\", \"$FLOW_LOG_METADATA_CONFIGURATION\", \"$FLOW_LOGS_ENABLED\", \"$FLOW_LOG_STATUS_MESSAGE\", \"$FLOW_LOG_SAMPLE_RATE_STATUS_MESSAGE\"";
			fi;		

		done;

	else
		if [[ $CSV != "True" ]]; then
			echo "No subnets found for project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
	fi;
	sleep $SLEEP_SECONDS;
done;

