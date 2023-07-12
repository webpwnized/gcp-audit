#!/bin/bash

source functions.inc

PROJECT_IDS="";
DEBUG="False";
HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 		set -- "$@" "-h" ;;
    "--debug") 		set -- "$@" "-d" ;;
    "--project")   	set -- "$@" "-p" ;;
    *)        		set -- "$@" "$arg"
  esac
done

while getopts "hdp:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_IDS=${OPTARG};;
        d)
        	DEBUG="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

for PROJECT_ID in $PROJECT_IDS; do	
    PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
	PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
	PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

	set_project $PROJECT_ID;

	if ! api_enabled compute.googleapis.com; then
		echo "Compute Engine API is not enabled on Project $PROJECT_ID"
		continue
	fi
	
	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	if [[ $INSTANCES != "[]" ]]; then
	
		echo "---------------------------------------------------------------------------------";
		echo "Instances for Project $PROJECT_ID";
        echo "Project Application: $PROJECT_APPLICATION";
	    echo "Project Owner: $PROJECT_OWNER";
		echo "---------------------------------------------------------------------------------";

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do
		
			NAME=$(echo $INSTANCE | jq -rc '.name');
			BLOCK_PROJECT_WIDE_SSH_KEYS=$(echo $INSTANCE | jq -rc '.metadata.items[] | select(.key=="block-project-ssh-keys")' | jq -rc '.value' );
						
			if [[ $BLOCK_PROJECT_WIDE_SSH_KEYS != "true" ]]; then
				echo "Instance Name: $NAME";
				echo "VIOLATION: Project-wide SSH keys allowed"
			fi;
			echo "";
		done;
		echo "";
	else
		echo "No instances found for Project $PROJECT_ID";
		echo "";
	fi;
	sleep 0.5;
done;

