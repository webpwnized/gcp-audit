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
        "--help")           set -- "$@" "-h" ;;
        "--debug")          set -- "$@" "-d" ;;
        "--csv")            set -- "$@" "-c" ;;
        "--project")        set -- "$@" "-p" ;;
        *)                  set -- "$@" "$arg"
    esac
done

while getopts "hdcp:" option; do
    case "${option}" in
        p)
            PROJECT_IDS=${OPTARG};;
        d)
            DEBUG="True";;
        c)
            CSV="True";;
        h)
            echo "$HELP"; 
            exit 0;;
    esac;
done;


if [[ $PROJECT_IDS == "" ]]; then
    read -p "Enter project IDs (separated by space): " PROJECT_IDS
fi;

if [[ $DEBUG == "True" ]]; then
    echo "Projects: $PROJECT_IDS";
    echo $BLANK_LINE;
fi;

if [[ $CSV == "True" ]]; then
    echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"INSTANCE_NAME\", \"ENABLED_SERIAL_PORTS\", \"ENABLED_SERIAL_PORT_LOGGING\", \"VIOLATION_SERIAL_PORTS\", \"VIOLATION_SERIAL_PORT_LOGGING\"";
fi;

for PROJECT_ID in $PROJECT_IDS; do

    set_project $PROJECT_ID;

    if ! api_enabled compute.googleapis.com; then
        if [[ $CSV != "True" ]]; then
            echo "Compute Engine API is not enabled on Project $PROJECT_ID";
            continue;
        fi;
    fi;

    declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

    if [[ $DEBUG == "True" ]]; then
        echo "Instances (JSON): $INSTANCES";
        echo $BLANK_LINE;
    fi;

    if [[ $INSTANCES != "[]" ]]; then

            #Get project details
            get_project_details $PROJECT_ID

        echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do
        
            if [[ $DEBUG == "True" ]]; then
                echo "Instance (JSON): $INSTANCES";
                echo $BLANK_LINE;
            fi;

            INSTANCE_NAME=$(echo $INSTANCE | jq -rc '.name');
            ENABLED_SERIAL_PORTS=$(echo $INSTANCE | jq -rc '.metadata.items[] | select(.key=="serial-port-enable")' | jq -rc '.value' | tr '[:upper:]' '[:lower:]' );
            ENABLED_SERIAL_PORT_LOGGING=$(echo $INSTANCE | jq -rc '.metadata.items[] | select(.key=="serial-port-logging-enable")' | jq -rc '.value' | tr '[:upper:]' '[:lower:]' );
            VIOLATION_SERIAL_PORTS="False";
            VIOLATION_SERIAL_PORT_LOGGING="False";

            if [[ $DEBUG == "True" ]]; then
                echo "Instance Metadata (JSON): $(echo $INSTANCE | jq -rc '.metadata.items[]')";
                echo $BLANK_LINE;
            fi;
            
            if [[ $ENABLED_SERIAL_PORTS == "" ]]; then
                ENABLED_SERIAL_PORTS="false";
            fi;
            
            if [[ $ENABLED_SERIAL_PORT_LOGGING == "" ]]; then
                ENABLED_SERIAL_PORT_LOGGING="false";
            fi;           
            
            if [[ $ENABLED_SERIAL_PORTS == "true" ]]; then
                VIOLATION_SERIAL_PORTS="True";
            fi;
            
            if [[ $ENABLED_SERIAL_PORT_LOGGING != "true" ]]; then
                VIOLATION_SERIAL_PORT_LOGGING="True";
            fi;

            # Print the results gathered above
            if [[ $CSV != "True" ]]; then
                echo "Project ID: $PROJECT_ID";
                echo "Project Name: $PROJECT_NAME";
                echo "Project Application: $PROJECT_APPLICATION";
                echo "Project Owner: $PROJECT_OWNER";
                echo "Instance Name: $INSTANCE_NAME";
                echo "Serial Port Setting: $ENABLED_SERIAL_PORTS";
                echo "Serial Port Status: VIOLATION: $VIOLATION_SERIAL_PORTS";
                echo "Serial Port Logging Setting: $ENABLED_SERIAL_PORT_LOGGING";
                echo "Serial Port Logging Status: VIOLATION: $VIOLATION_SERIAL_PORT_LOGGING";
                echo $BLANK_LINE;
            else
                echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$INSTANCE_NAME\", \"$ENABLED_SERIAL_PORTS\", \"$ENABLED_SERIAL_PORT_LOGGING\", \"$VIOLATION_SERIAL_PORTS\", \"$VIOLATION_SERIAL_PORT_LOGGING\"";
            fi;       

        done;
        echo $BLANK_LINE;
    else
        if [[ $CSV != "True" ]]; then
            echo "No instances found for project $PROJECT_ID";
            echo $BLANK_LINE;
        fi;
    fi;
    sleep $SLEEP_SECONDS;
done;
