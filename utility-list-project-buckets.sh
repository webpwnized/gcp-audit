#!/bin/bash

source functions.inc

declare SEPARATOR="---------------------------------------------------------------------------------";
declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare ICH="False";
declare HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-c, --csv] [-i, --include-column-headers] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 			set -- "$@" "-h" ;;
    "--debug") 			set -- "$@" "-d" ;;
    "--csv") 			set -- "$@" "-c" ;;
    "--include-column-headers") set -- "$@" "-i" ;;
    "--project")   		set -- "$@" "-p" ;;
    *)        			set -- "$@" "$arg"
  esac
done

while getopts "hdcip:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_IDS=${OPTARG};;
        d)
        	DEBUG="True";;
        c)
        	CSV="True";;
	i)
		ICH="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;

if [[ $PROJECT_IDS == "" ]]; then
	declare PROJECT_IDS=$(get_projects);
fi;

if [[ $ICH == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"BUCKET_NAME\"";
fi;

for PROJECT_ID in $PROJECT_IDS; do

	set_project $PROJECT_ID;

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

