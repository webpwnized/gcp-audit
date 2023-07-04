#!/bin/bash

source functions.inc

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
    declare PROJECT_IDS=$(gcloud projects list --format="json");
else
    declare PROJECT_IDS=$(gcloud projects list --format="json" --filter="name:$PROJECT_IDS");
fi;

declare SEPARATOR="----------------------------------------------------------------------------------------";

if [[ $PROJECT_IDS != "[]" ]]; then

    if [[ $ICH == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"FIREWALL_RULE_NAME\", \"LOG_CONFIG\", \"LOG_CONFIG_STATUS_MESSAGE\"";	
    fi;

    echo $PROJECT_IDS | jq -rc '.[]' | while IFS='' read PROJECT_ID;do

	if ! api_enabled compute.googleapis.com; then
		echo "Compute Engine API is not enabled on Project $PROJECT_ID"
		continue
	fi

	# Get the project details
	PROJECT_ID=$(echo $PROJECT_ID | jq -r '.projectId');
	PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
	PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
	PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
	PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

	set_project $PROJECT_ID;

	declare RESULTS=$(gcloud compute firewall-rules list --quiet --format="json");

	if [[ $RESULTS != "[]" ]]; then

		if [[ $CSV != "True" ]]; then
			echo $SEPARATOR;
			echo "Firewall rules for project $PROJECT_ID";
			echo "";
		fi;
		
		#Loop through each firewall rule in the project
		echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r FIREWALL_RULE;do

			# Debugging output
			if [[ $DEBUG == "True" ]]; then
				echo $FIREWALL_RULE | jq '.';
			fi;

			FIREWALL_RULE_NAME=$(echo $FIREWALL_RULE | jq -rc '.name');
			LOG_CONFIG=$(echo $FIREWALL_RULE | jq -rc '.logConfig.enable // false');

			# Calculate Logging Violations			
			if [[ $LOG_CONFIG == "false" ]]; then
				LOG_CONFIG_STATUS_MESSAGE="VIOLATION: Firewall logging is not enabled";
			else
				LOG_CONFIG_STATUS_MESSAGE="Firewall logging is enabled";
			fi;
				
			if [[ $CSV != "True" ]]; then
				# Print Project Information
				echo "Name: $FIREWALL_RULE_NAME";
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";
				echo "Logging: $LOG_CONFIG";
				echo $LOG_CONFIG_STATUS_MESSAGE;
				echo "";
			else
				echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$FIREWALL_RULE_NAME\", \"$LOG_CONFIG\", \"$LOG_CONFIG_STATUS_MESSAGE\"";
			fi;
		done;
	else
		if [[ $CSV != "True" ]]; then
			echo $SEPARATOR;
			echo "No firewall rules found for $PROJECT_ID";
			echo "";
		fi;
	fi;
	sleep 0.5;
    done;
else
	if [[ $CSV != "True" ]]; then
    		echo "No projects found";
    		echo "";
	fi;
fi;

