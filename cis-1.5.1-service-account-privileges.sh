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
