#!/bin/bash

api_enabled(){

	local API_NAME=$1;
	local NOT_ENABLED=0;
	local ENABLED=1;

	if [[ $(gcloud services list --quiet --enabled --filter="NAME=$API_NAME" 2>/dev/null | grep -c $API_NAME) -ge 1 ]]; then
		return $NOT_ENABLED;
	else
		return $ENABLED;
	fi;
}

function get_projects() {

	local PROJECT_ID=$1;
	
	if [[ $PROJECT_ID == "" ]]; then
		# Get all projects
		gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2;
	else
		# User wants to look at a specific project
		echo "$PROJECT_ID";
	fi;
}

function set_project() {
    local PROJECT_ID=$1;
    gcloud config set project $PROJECT_ID 2>/dev/null;
}
