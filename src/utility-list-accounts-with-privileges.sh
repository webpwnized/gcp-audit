#!/bin/bash

source common-constants.inc;

declare ROLE="owner";
declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
	$0 [-r,--role] [-p, --project PROJECT] [-c, --csv] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 			set -- "$@" "-h" ;;
    "--debug") 			set -- "$@" "-d" ;;
    "--csv") 			set -- "$@" "-c" ;;
    "--role") 			set -- "$@" "-r" ;;
    "--project")   		set -- "$@" "-p" ;;
    *)        			set -- "$@" "$arg"
  esac
done

while getopts "hdcp:r:" option
do 
    case "${option}"
        in
        r)
        	ROLE=${OPTARG};;
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
    declare PROJECT_IDS=$(gcloud projects list --format="json");
else
    declare PROJECT_IDS=$(gcloud projects list --format="json" --filter="name:$PROJECT_IDS");
fi;

if [[ $PROJECT_IDS != "[]" ]]; then

    if [[ $CSV == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"ACCOUNT\", \"ACCOUNT_TYPE\", \"ENVIRONMENT\"";
    fi;

    echo $PROJECT_IDS | jq -rc '.[]' | while IFS='' read PROJECT;do

		PROJECT_ID=$(echo $PROJECT | jq -r '.projectId');
			PROJECT_NAME=$(echo $PROJECT | jq -r '.name');
			PROJECT_OWNER=$(echo $PROJECT | jq -r '.labels.adid');
			PROJECT_APPLICATION=$(echo $PROJECT | jq -r '.labels.app');
			MEMBERS=$(gcloud projects get-iam-policy $PROJECT_ID --format="json" | jq -r '.bindings[] | select(.role=="roles/'$ROLE'") | .members[]');
			ENVIRONMENT="";
			
			for ENV in "sandbox" "dev" "sys" "uat" "prod"; do
			if [[ $(grep -ic $ENV <<< $PROJECT_ID) == 1 ]]; then
				ENVIRONMENT=$ENV;
			fi;
		done;

        if [[ $MEMBERS != "" ]]; then
        	if [[ $CSV != "True" ]]; then
        		echo "Project ID: $PROJECT_ID";
			echo "Project Name: $PROJECT_NAME";
			echo "Project Owner: $PROJECT_OWNER";
			echo "Project Application: $PROJECT_APPLICATION";            
			echo -e "Members ($ROLE role):\n$MEMBERS";
			echo "Environment: $ENVIRONMENT";
            		echo $BLANK_LINE;
        	else
        		for MEMBER in $MEMBERS;do
        			ACCOUNT_TYPE=$(echo $MEMBER | cut -d ":" -f1);
        			ACCOUNT=$(echo $MEMBER | cut -d ":" -f2);
        			echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$ACCOUNT\", \"$ACCOUNT_TYPE\", \"$ENVIRONMENT\"";
        		done;
        	fi;
        fi;
		sleep $SLEEP_SECONDS;
    done;
else
	if [[ $CSV != "True" ]]; then
    		echo "No projects found";
    		echo $BLANK_LINE;
	fi;
fi;
