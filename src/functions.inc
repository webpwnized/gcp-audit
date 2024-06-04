#!/bin/bash

# Function to print debug information about projects
debug_projects() {
    if [[ $DEBUG == "True" ]]; then
        echo "DEBUG: Projects: $PROJECTS"
        echo "$BLANK_LINE"
    fi
}

# Function to print debug information about JSON data
debug_json() {
    local DATA_TYPE=$1
    local PROJECT_ID=$2
    local JSON_DATA=$3

    if [[ $DEBUG == "True" ]]; then
        echo "PROJECT: $PROJECT_ID:"
        echo "DEBUG: $DATA_TYPE (JSON):"
        echo "$(jq -C '.' <<< "$JSON_DATA")"
        echo "$BLANK_LINE"
    fi
}

# Function to print a message when no output is returned
function no_output_returned() {
    local MESSAGE=$1

    if [[ $CSV != "True" ]]; then
        echo "$MESSAGE"
        echo "$BLANK_LINE"
    fi
}

# Function to encode double quotes by doubling them
encode_double_quotes() {
    local input="$1"
    echo "$input" | sed 's/"/""/g'
}

# Function to log error to file
log_error() {
    local ERROR_MESSAGE="$1"
    local CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$CURRENT_TIME] ERROR: $ERROR_MESSAGE" >> "$ERROR_LOG_FILE"
}

# Function to delete $ERROR_LOG_FILE if it is empty
delete_empty_error_log() {
    local LOG_FILE="$1"

    # Check if the log file is empty
    if [[ ! -s "$LOG_FILE" ]]; then
        # Delete the file if it's empty
        rm -f "$LOG_FILE"
    fi
}

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


# Function to get project details project_name, project_application, project_owner
function get_project_details() {
  local PROJECT_ID=$1;

  PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json")
  PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name')
  PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app // empty')
  PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid // empty')
}


