#!/bin/bash

PROJECT_IDS="";
DEBUG="False";
CSV="False";
HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-d, --debug] [-h, --help]	
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

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

for PROJECT_ID in $PROJECT_IDS; do
	gcloud config set project $PROJECT_ID 2>/dev/null;
	sleep 0.5;
	
	if [[ $(gcloud services list --enabled --filter="NAME=compute.googleapis.com" | grep -c "compute.googleapis.com") == 0 ]]; then
		if [[ $CSV != "True" ]]; then
			echo "Compute Engine API is not enabled for Project $PROJECT_ID.";
		fi;
		continue;
	fi;

	declare PROJECT_INFO=$(gcloud compute project-info describe --format="json");

	if [[ $PROJECT_INFO != "" ]]; then

		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');
	
		if [[ $CSV != "True" ]]; then
			echo "---------------------------------------------------------------------------------";
			echo "OS Login for Project $PROJECT_ID";
			echo "---------------------------------------------------------------------------------";
		fi;

		# Checking the project level confirguration
		OSLOGIN_ENABLED_PROJECT=$(echo $PROJECT_INFO | jq -rc '.commonInstanceMetadata.items[] | with_entries( .value |= ascii_downcase ) | select(.key=="enable-oslogin") | select(.value=="true")' );

		if [[ $OSLOGIN_ENABLED_PROJECT == "" ]]; then
			echo "VIOLATION: OS Login is NOT enabled at the Project level";
		else
			echo "COMMENT: OS Login is enabled at the project level, but we need to check if OS Login is enabled at the instance level.";
		fi;
		echo "";
	else
		echo "No project information found for Project $PROJECT_ID";
		echo "";
	fi;

	# Checking the instance level configuration	
	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	if [[ $INSTANCES != "[]" ]]; then
		
		echo "---------------------------------------------------------------------------------";
		echo "Instances for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do

			NAME=$(echo $INSTANCE | jq -rc '.name');			
			OSLOGIN_CONFIGURED=$(echo $INSTANCE | jq -rc '.metadata.items[] | with_entries( .value |= ascii_downcase ) | select(.key=="enable-oslogin")' );
		
			if [[ $OSLOGIN_CONFIGURED == "" && $OSLOGIN_ENABLED_PROJECT == "" ]]; then
				echo "PASSED: OS Login is enabled at the project level but not the instance level";
			elif [[ $OSLOGIN_CONFIGURED != "" ]]; then
				echo "Instance Name: $NAME";
				if [[ $OSLOGIN_ENABLED_PROJECT == "" ]]; then
					echo "VIOLATION: OS Login is NOT enabled at the project level but IS enabled at the instance level. OS Login must be enabled but ONLY at the project level";
				else
					echo "VIOLATION: OS Login is enabled at the project level AND at the instance level. OS Login must be enabled but ONLY at the project level";
				fi;
				echo "";
			fi;
		done;
		echo "";
	else
		echo "No instances found for Project $PROJECT_ID";
		echo "";
	fi;
done;

