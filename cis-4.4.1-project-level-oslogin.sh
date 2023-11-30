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
    "--project")	   	set -- "$@" "-p" ;;
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

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

if [[ $DEBUG == "True" ]]; then
	echo "Projects: $PROJECT_IDS";
	echo $BLANK_LINE;
fi;

if [[ $CSV == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"INSTANCE\", \"INSTANCE_NAME\", \"VIOLATION_FLAG\", \"OSLOGIN_ENABLED_INSTANCE_STATUS_MESSAGE\"";
fi;

for PROJECT_ID in $PROJECT_IDS; do
	set_project $PROJECT_ID;

	if ! api_enabled compute.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "COMMENT: Compute Engine API is not enabled for Project $PROJECT_ID.";
		fi;
		continue
	fi

	declare PROJECT_INFO=$(gcloud compute project-info describe --format="json");

	if [[ $DEBUG == "True" ]]; then
		echo "Project Info (JSON): $PROJECT_INFO";
		echo $BLANK_LINE;
	fi;

	if [[ $PROJECT_INFO != "" ]]; then

      		#Get project details
      		get_project_details $PROJECT_ID

		# Checking the project level confirguration
		OSLOGIN_ENABLED_PROJECT=$(echo $PROJECT_INFO | jq -rc '.commonInstanceMetadata.items[] | with_entries( .value |= ascii_downcase ) | select(.key=="enable-oslogin") | select(.value=="true") // empty' );
		VIOLATION_FLAG="False";

		if [[ $OSLOGIN_ENABLED_PROJECT == "" ]]; then
			OSLOGIN_ENABLED_PROJECT_STATUS_MESSAGE="VIOLATION: OS Login is NOT enabled at the Project level";
			VIOLATION_FLAG="True";
		else
			OSLOGIN_ENABLED_PROJECT_STATUS_MESSAGE="COMMENT: OS Login is enabled at the project level, but we need to check if OS Login is enabled at the instance level";
			VIOLATION_FLAG="False";
		fi;
	else
		if [[ $CSV != "True" ]]; then
			echo "No project information found for Project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
	fi;
	
	#Output results for Project level
	if [[ $CSV != "True" ]]; then
		echo "Project ID: $PROJECT_ID";
		echo "Project Name: $PROJECT_NAME";
		echo "Project Application: $PROJECT_APPLICATION";
		echo "Project Owner: $PROJECT_OWNER";
		echo "Level: Project";
		echo "Project Name: $PROJECT_NAME";
		echo "Status: $OSLOGIN_ENABLED_PROJECT_STATUS_MESSAGE";
		echo $BLANK_LINE;
	else
		echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$PROJECT\", \"$PROJECT_NAME\", \"$VIOLATION_FLAG\", \"$OSLOGIN_ENABLED_PROJECT_STATUS_MESSAGE\"";
	fi;	
	
	# Checking the instance level configuration	
	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	if [[ $INSTANCES != "[]" ]]; then
		
		if [[ $CSV != "True" ]]; then
			echo $SEPARATOR;
			echo "Instances for Project $PROJECT_ID";
			echo $SEPARATOR;
		fi;

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do

			if [[ $DEBUG == "True" ]]; then
				echo "Instance (JSON): $INSTANCE"; 
			fi;

			INSTANCE_NAME=$(echo $INSTANCE | jq -rc '.name');			
			OSLOGIN_ENABLED_INSTANCE=$(echo $INSTANCE | jq -rc '.metadata.items[] | with_entries( .value |= ascii_downcase ) | select(.key=="enable-oslogin") // empty' );
			VIOLATION_FLAG="False";

			if [[ $OSLOGIN_ENABLED_PROJECT != "" && $OSLOGIN_ENABLED_INSTANCE == "" ]]; then
				OSLOGIN_ENABLED_INSTANCE_STATUS_MESSAGE="PASSED: OS Login is enabled at the project level but not the instance level";
				VIOLATION_FLAG="False";
			elif [[ $OSLOGIN_ENABLED_INSTANCE == "" ]]; then
				OSLOGIN_ENABLED_INSTANCE_STATUS_MESSAGE="COMMENT: Ignoring instance $NAME. OS Login is not enable on this instance.";
				VIOLATION_FLAG="False";
			elif [[ $OSLOGIN_ENABLED_INSTANCE != "" ]]; then
				if [[ $OSLOGIN_ENABLED_PROJECT != "" ]]; then
					OSLOGIN_ENABLED_INSTANCE_STATUS_MESSAGE="VIOLATION: OS Login is enabled at the project level AND at the instance level. OS Login must be enabled but ONLY at the project level";
					VIOLATION_FLAG="True";
				else
					OSLOGIN_ENABLED_INSTANCE_STATUS_MESSAGE="VIOLATION: OS Login is NOT enabled at the project level but IS enabled at the instance level. OS Login must be enabled but ONLY at the project level";
					VIOLATION_FLAG="True";
				fi;
			fi;

			#Output results for Instance level
			if [[ $CSV != "True" ]]; then
				echo "Project ID: $PROJECT_ID";
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";
				echo "Level: Instance";
				echo "Instance Name: $INSTANCE_NAME";
				echo "Status: $OSLOGIN_ENABLED_INSTANCE_STATUS_MESSAGE";
				echo $BLANK_LINE;
			else
				echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$INSTANCE\", \"$INSTANCE_NAME\", \"$VIOLATION_FLAG\", \"$OSLOGIN_ENABLED_INSTANCE_STATUS_MESSAGE\"";
			fi;
			
		done;
	else
		if [[ $CSV != "True" ]]; then
			echo "COMMENT: No instances found for Project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
	fi;
	
	sleep $SLEEP_SECONDS;
done;

