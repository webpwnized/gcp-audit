#!/bin/bash

source common-constants.inc;
source functions.inc;

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

	set_project $PROJECT_ID;

	if ! api_enabled compute.googleapis.com; then
		echo "Compute Engine API is not enabled on Project $PROJECT_ID"
		continue
	fi

	#Get project details
      	get_project_details $PROJECT_ID

	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	if [[ $INSTANCES != "[]" ]]; then
	
		echo "---------------------------------------------------------------------------------";
		echo "Instances for Project $PROJECT_ID";
        echo "Project Application: $PROJECT_APPLICATION";
	    echo "Project Owner: $PROJECT_OWNER";
		echo "---------------------------------------------------------------------------------";

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do

			NAME=$(echo $INSTANCE | jq -rc '.name');
			SHIELDED_INSTANCE_CONFIG=$(echo $INSTANCE | jq -rc '.shieldedInstanceConfig');
			ENABLE_INTEGRITY_MONITORING=$(echo $INSTANCE | jq -rc '.shieldedInstanceConfig.enableIntegrityMonitoring' | tr '[:upper:]' '[:lower:]');
			ENABLE_SECURE_BOOT=$(echo $INSTANCE | jq -rc '.shieldedInstanceConfig.enableSecureBoot' | tr '[:upper:]' '[:lower:]');
			ENABLE_VTPM=$(echo $INSTANCE | jq -rc '.shieldedInstanceConfig.enableVtpm' | tr '[:upper:]' '[:lower:]');
						
			if [[ $SHIELDED_INSTANCE_CONFIG =~ "false" ]]; then
				echo "Instance Name: $NAME";
				echo "Shielded instance Configuration: $SHIELDED_INSTANCE_CONFIG";
				if [[ $ENABLE_INTEGRITY_MONITORING == "false" ]]; then
					echo "VIOLATION: Integrity monitoring is not enabled";
				fi;
				if [[ $ENABLE_SECURE_BOOT == "false" ]]; then
					echo "VIOLATION: Secure boot is not enabled";
				fi;
				if [[ $ENABLE_VTPM == "false" ]]; then
					echo "VIOLATION: Virtual TPM is not enabled";
				fi;
				echo $BLANK_LINE;
			fi;
		done;
		echo $BLANK_LINE;
	else
		echo "No instances found for Project $PROJECT_ID";
		echo $BLANK_LINE;
	fi;
	sleep $SLEEP_SECONDS;
done;

