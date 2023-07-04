#!/bin/bash

source functions.inc

declare RESULTS=$(gcloud projects list --format="json");

declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
	$0 [-c, --csv] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 	set -- "$@" "-h" ;;
    "--debug") 	set -- "$@" "-d" ;;
    "--csv") 	set -- "$@" "-c" ;;
    *)        	set -- "$@" "$arg"
  esac
done

while getopts "hdcp:" option
do 
    case "${option}"
        in
        d)
        	DEBUG="True";;
        c)
        	CSV="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;

if [[ $RESULTS != "[]" ]]; then
	if [[ $CSV == "True" ]]; then
		echo "\"PROJECT_NAME\",\"PROJECT_APPLICATION\",\"PROJECT_OWNER\"";
	fi
		
	echo $RESULTS | jq -rc '.[]' | while IFS='' read PROJECT; do

		NAME=$(echo $PROJECT | jq -rc '.name');
		APPLICATION=$(echo $PROJECT | jq -rc '.labels.app');
		OWNER=$(echo $PROJECT | jq -rc '.labels.adid');

		if [[ $CSV == "True" ]]; then
			echo "\"$NAME\",\"$APPLICATION\",\"$OWNER\"";
		else
			echo "$NAME ($APPLICATION): $OWNER";
		fi;
	done;
else
	echo "No projects found";
	echo "";
fi;

