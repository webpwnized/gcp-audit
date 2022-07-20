#!/bin/bash

LONG=project:
SHORT=p:
OPTS=$(getopt -a -n testscript --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"
while :
do
    case "$1" in --project | -p )
        declare PROJECT_IDS="$2"
        shift 2
     ;;
     -- )
        shift;
        break
        ;;
        *)
        exit 2
    esac
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

declare SEPARATOR="---------------------------------------------------------------------------------";

for PROJECT_ID in $PROJECT_IDS; do	
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

