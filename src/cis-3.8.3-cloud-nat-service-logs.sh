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
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

declare SEPARATOR="----------------------------------------------------------------------------------------";

if [[ $CSV == "True" ]]; then
	echo "\"PROJECT_NAME\", \"PROJECT_APPLICATION\", \"PROJECT_OWNER\", \"CLOUD_NAT_NAME\", \"CLOUD_NAT_ROUTER\", \"LOG_CONFIG\", \"LOG_CONFIG_STATUS_MESSAGE\"";	
fi;

for PROJECT_ID in $PROJECT_IDS; do
	set_project $PROJECT_ID;

	if ! api_enabled compute.googleapis.com; then
		echo "Compute Engine API is not enabled on Project $PROJECT_ID"
		continue
	fi


	#Get project details
    	get_project_details $PROJECT_ID

	declare RESULTS=$(gcloud compute routers list --project $PROJECT_ID --format="json");

	if [[ $RESULTS != "[]" ]]; then
		if [[ $CSV != "True" ]]; then
			echo $SEPARATOR;
			echo "Cloud NAT services for project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;

		echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r ROUTER;do
			ROUTER_NAME=$(echo $ROUTER | jq -rc '.name');
			ROUTER_REGION=$(echo $ROUTER | jq -rc '.region');

			# Debugging output for router
			if [[ $DEBUG == "True" ]]; then
			echo "Router details:"
				echo $ROUTER | jq '.';
			fi;

			NATS=$(gcloud compute routers nats list --router=$ROUTER_NAME --router-region=$ROUTER_REGION --project=$PROJECT_ID --format="json");
			echo $NATS | jq -r -c '.[]' | while IFS='' read -r NAT; do
				NAT_NAME=$(echo $NAT | jq -rc '.name');
				LOG_CONFIG=$(echo $NAT | jq -rc '.logConfig.enable // false');

				# Debugging output for Cloud NAT
				if [[ $DEBUG == "True" ]]; then
					echo "Cloud NAT details:"
					echo $NAT | jq '.';
				fi;


				if [[ $LOG_CONFIG == "false" ]]; then
					LOG_CONFIG_STATUS_MESSAGE="VIOLATION:Cloud NAT logging is not enabled";
				else
					LOG_CONFIG_STATUS_MESSAGE="Cloud NAT logging is enabled";
				fi;

				if [[ $CSV != "True" ]]; then
					echo "Cloud NAT Name: $NAT_NAME";
					echo "Cloud NAT Router: $ROUTER_NAME";
					echo "Project Name: $PROJECT_NAME";
					echo "Project Application: $PROJECT_APPLICATION";
					echo "Project Owner: $PROJECT_OWNER";
					echo "Logging Enabled: $LOG_CONFIG";
					echo "Logging Status: $LOG_CONFIG_STATUS_MESSAGE";
					echo $BLANK_LINE;
				else
			echo "\"$PROJECT_NAME\", \"$PROJECT_APPLICATION\",\"$PROJECT_OWNER\", \"$NAT_NAME\", \"$ROUTER_NAME\", \"$LOG_CONFIG\", \"$LOG_CONFIG_STATUS_MESSAGE\"";
				fi;
			done;
		done;
	else
		if [[ $CSV != "True" ]]; then
			echo $SEPARATOR;
			echo "No Cloud NAT services for project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
	fi;
	sleep $SLEEP_SECONDS;
done;



