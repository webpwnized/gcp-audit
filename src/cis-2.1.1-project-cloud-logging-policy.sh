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

    # Get project details
    get_project_details $PROJECT_ID

    echo "IAM Policy for Project $PROJECT_ID"
    echo "Project Application: $PROJECT_APPLICATION";
    echo "Project Owner: $PROJECT_OWNER"; 
    echo $BLANK_LINE;
    gcloud projects get-iam-policy $PROJECT_ID;
    echo $BLANK_LINE;
    sleep $SLEEP_SECONDS;
done;
