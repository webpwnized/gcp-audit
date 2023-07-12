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

	echo "Project $PROJECT_ID"
    echo "Project Application: $PROJECT_APPLICATION";
	echo "Project Owner: $PROJECT_OWNER";
    
	declare ACCOUNTS=$(gcloud projects get-iam-policy $PROJECT_ID --format=json | jq -r '.bindings[] | .role, .members[]')
	for ACCOUNT in $ACCOUNTS; do
		if [[ $ACCOUNT =~ 'roles' ]]; then
			echo ""
			echo ""
			echo $ACCOUNT
			echo "----------------------------"
		else
			echo $ACCOUNT
		fi
	done;
	echo ""
done;
