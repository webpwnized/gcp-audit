#!/bin/bash

source helpers.inc

declare SEPARATOR="---------------------------------------------------------------------------------";
declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [--csv] [-d, --debug] [-h, --help]	
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

	if ! api_enabled storage.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "Storage API is not enabled on Project $PROJECT_ID";
			echo "";
		fi;
		continue;
	fi

	declare BUCKET_NAMES=$(gsutil ls);
	
	if [[ $DEBUG == "True" ]]; then
		echo "Buckets: $BUCKET_NAMES";
		echo "";
	fi;

	if [[ $BUCKET_NAMES != "" ]]; then

		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');
	
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
				echo "";
			else
				echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$BUCKET_NAME\"";
			fi;

		done;
		echo "";
	else
		if [[ $CSV != "True" ]]; then
			echo "No storage buckets found for Project $PROJECT_ID";
			echo "";
		fi;
	fi;
	sleep 0.5;
done;

