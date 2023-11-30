#!/bin/bash

source ./common-constants.inc;
source ./functions.inc;

function output_header() {
	if [[ $CSV == "True" ]]; then
		output_csv_header;
	fi;
};

function output_csv_header() {
	echo "\"PROJECT_NAME\", \"PROJECT_APPLICATION\", \"PROJECT_OWNER\", \"INSTANCE_NAME\", \"INSTANCE_ALLOWS_PROJECT_WIDE_SSH_KEYS_FLAG\", \"INSTANCE_STATUS\"";
};

function output_instance_csv() {
	echo "\"$PROJECT_NAME\", \"$PROJECT_APPLICATION\", \"$PROJECT_OWNER\", \"$INSTANCE_NAME\", \"$INSTANCE_ALLOWS_PROJECT_WIDE_SSH_KEYS_FLAG\", \"$INSTANCE_STATUS\"";
};

function output_instance() {
	if [[ $CSV == "True" ]]; then
		output_instance_csv;
	else
		output_instance_text;
	fi;
};

function output_instance_text() {
	echo "Project Name: $PROJECT_NAME";
	echo "Project Application: $PROJECT_APPLICATION";
	echo "Project Owner: $PROJECT_OWNER";
	echo "Instance Name: $INSTANCE_NAME";
	echo "Instance Status: $INSTANCE_STATUS";
	echo $BLANK_LINE;
};

function parse_instance() {
	local l_INSTANCE=$1;

	INSTANCE_NAME=$(echo $l_INSTANCE | jq -rc '.name');
	BLOCK_PROJECT_WIDE_SSH_KEYS=$(echo $INSTANCE | jq -rc '.metadata.items[] | select(.key=="block-project-ssh-keys")' | jq -rc '.value' );
	
	INSTANCE_STATUS="INFO: Instance does not allow Project-wide SSH keys";
	INSTANCE_ALLOWS_PROJECT_WIDE_SSH_KEYS_FLAG="False";
	if [[ $BLOCK_PROJECT_WIDE_SSH_KEYS != "true" ]]; then
		INSTANCE_STATUS="VIOLATION: Instance allows Project-wide SSH keys";
		INSTANCE_ALLOWS_PROJECT_WIDE_SSH_KEYS_FLAG="True";
	fi;
};

source ./standard-menu.inc;

if [[ $PROJECT_ID == "" ]]; then
    declare PROJECTS=$(gcloud projects list --format="json");
else
    declare PROJECTS=$(gcloud projects list --format="json" --filter="name:$PROJECT_ID");
fi;

if [[ $DEBUG == "True" ]]; then
	echo "Projects: $PROJECTS";
	echo $BLANK_LINE;
fi;

if [[ $PROJECTS != "[]" ]]; then

	output_header;
		
	echo $PROJECTS | jq -rc '.[]' | while IFS='' read PROJECT;do


		PROJECT_ID=$(echo $PROJECT | jq -r '.projectId');
		
		set_project $PROJECT_ID;
	
		if ! api_enabled compute.googleapis.com; then
			if [[ $CSV != "True" ]]; then
				echo "Compute Engine API is not enabled for Project $PROJECT_ID.";
			fi;
			continue;
		fi;
	
		declare INSTANCES=$(gcloud compute instances list --quiet --format="json(name, metadata.items)");

		if [[ $DEBUG == "True" ]]; then
			echo "Instances (JSON): $INSTANCES";
			echo $BLANK_LINE;
		fi;
		
		if [[ $INSTANCES != "[]" ]]; then
		
			#Get project details
      			get_project_details $PROJECT_ID;
      			
      			# "read -r" ensures the backslashes in the JSON are not consumed by "read()" 
      			echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do

      				if [[ $DEBUG == "True" ]]; then
					echo "Instance (JSON): $INSTANCE";
					echo $BLANK_LINE;
				fi;
      			
				parse_instance "$INSTANCE";				
				output_instance;
			done;
		else
			if [[ $CSV == "False" ]]; then
				echo "No instances found for project $PROJECT_ID";
				echo $BLANK_LINE;
			fi;
		fi;
		
		sleep $SLEEP_SECONDS;
	done;
else
	if [[ $CSV == "False" ]]; then
		echo "No projects found";
		echo $BLANK_LINE;
	fi;
fi;

