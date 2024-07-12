#!/bin/bash

source common-constants.inc
source functions.inc

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
    "--project")   		set -- "$@" "-p" ;;
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

if [[ $CSV == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"BUCKET_NAME\"";
fi;

for PROJECT_ID in $PROJECT_IDS; do

	set_project $PROJECT_ID;

	if ! api_enabled storage.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "Storage API is not enabled on Project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
		continue;
	fi

	declare BUCKET_NAMES=$(gsutil ls);
	
	if [[ $DEBUG == "True" ]]; then
		echo "Buckets: $BUCKET_NAMES";
		echo $BLANK_LINE;
	fi;

	if [[ $BUCKET_NAMES != "" ]]; then

      		#Get project details
      		get_project_details $PROJECT_ID

		if [[ $CSV != "True" ]]; then
			echo $SEPARATOR;
			echo "Storage Buckets for Project $PROJECT_ID";
			echo $SEPARATOR;
		fi;
		
		for BUCKET_NAME in $BUCKET_NAMES; do

			if [[ $CSV != "True" ]]; then
				echo "Project ID: $PROJECT_ID";
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";
				echo "Bucket Name: $BUCKET_NAME";
				echo $BLANK_LINE;
			else
				echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$BUCKET_NAME\"";
			fi;

		done;
		echo $BLANK_LINE;
	else
		if [[ $CSV != "True" ]]; then
			echo "No storage buckets found for Project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
	fi;
	sleep $SLEEP_SECONDS;
done;

