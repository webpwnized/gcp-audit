#!/bin/bash

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
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

declare SEPARATOR="---------------------------------------------------------------------------------";

for PROJECT_ID in $PROJECT_IDS; do

    PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
	PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
	PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');	

	gcloud config set project $PROJECT_ID;

	declare BUCKETS=$(gsutil ls);
	
	echo $BUCKETS;

	if [[ $BUCKETS != "" ]]; then
	
		echo $SEPARATOR;
		echo "Storage Buckets for Project $PROJECT_ID";
		echo $SEPARATOR;
		
		for BUCKET in $BUCKETS; do
			declare PERMISSIONS=$(gsutil iam get $BUCKET);

			echo $SEPARATOR;
			echo "IAM Permissions for Bucket $BUCKET";
			echo $SEPARATOR;

			echo $PERMISSIONS | jq -r -c '.bindings[]' | while IFS='' read -r PERMISSION;do

				MEMBERS=$(echo $PERMISSION | jq -rc '.members[]');
				ROLE=$(echo $PERMISSION | jq '.role');

				echo "Project: $PROJECT_ID";
                echo "Project Application: $PROJECT_APPLICATION";
	            echo "Project Owner: $PROJECT_OWNER";
				echo "Bucket: $BUCKET";
				echo "Members: $MEMBERS";
				echo "Role: $ROLE";
				if [[ $ROLE =~ "allUsers" ]]; then echo "VIOLATION: Bucket publicly exposed to allUsers"; fi;
				if [[ $ROLE =~ "allAuthenticatedUsers" ]]; then echo "VIOLATION: Bucket publicly exposed to allAuthenticatedUsers"; fi;
				echo "";
			done;
		done;
		echo "";
	else
		echo "No storage buckets found for Project $PROJECT_ID";
		echo "";
	fi;
	sleep 0.5;
done;

