#!/bin/bash

source common-constants.inc;
source functions.inc

PROJECT_IDS="";
DEBUG="False";
CSV="False";
HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-d, --debug] [-c, --csv] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 		set -- "$@" "-h" ;;
    "--debug") 		set -- "$@" "-d" ;;
    "--project")   	set -- "$@" "-p" ;;
    "--csv")   	    set -- "$@" "-c" ;;
    *)        		set -- "$@" "$arg"
  esac
done

while getopts "hcdp:" option
do 
    case "${option}"
        in
        p) PROJECT_IDS=${OPTARG} ;;
        d) DEBUG="True" ;;
        c) CSV="True" ;;
        h) echo $HELP; exit 0 ;;
    esac;
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

# Print CSV header if CSV output is enabled
if [[ $CSV == "True" ]]; then
    echo "\"PROJECT_ID\", \"SERVIC_NAME\", \"SERVICE_INGRESS_SETTING\", \"VIOLATION\"";
fi

for PROJECT_ID in $PROJECT_IDS; do	
	set_project $PROJECT_ID;
    
    # Check if Cloud Run API is enabled for the project
    if ! api_enabled run.googleapis.com; then
        if [[ $CSV != "True" ]]; then
            echo "Cloud Run API is not enabled for Project $PROJECT_ID.";
            echo ""
        fi
        continue
    fi

    # Check if Compute Engine API is enabled for the project
    if ! api_enabled compute.googleapis.com; then
        if [[ $CSV != "True" ]]; then
            echo "Compute Engine API is not enabled for Project $PROJECT_ID.";
            echo ""
        fi
        continue
    fi

	declare SERVICES=$(gcloud run services list --quiet --format="json");

	if [[ $SERVICES != "[]" ]]; then
	    if [[ $CSV != "True" ]]; then
	    	echo "---------------------------------------------------------------------------------";
	    	echo "Cloud Run Services for Project $PROJECT_ID";
	    	echo "---------------------------------------------------------------------------------";
	    fi
	
		echo $SERVICES | jq -rc '.[]' | while IFS='' read -r SERVICE; do
			NAME=$(echo $SERVICE | jq -rc '.metadata.name');
			INGRESS_SETTING=$(echo $SERVICE | jq -rc '.metadata.annotations."run.googleapis.com/ingress"');
			
			if [[ $CSV == "True" ]]; then
			    VIOLATION="N/A";
			    if [[ $INGRESS_SETTING == "all" ]]; then
			        VIOLATION="The ingress setting is configured to ALL, which allows all requests including requests directly from the internet";
			    fi
			    echo "\"$PROJECT_ID\", \"$NAME\", \"$INGRESS_SETTING\", \"$VIOLATION\"";
			else
			    echo "Service Name: $NAME";
			    echo "Service Ingress Setting: $INGRESS_SETTING";
			    
			    if [[ $INGRESS_SETTING == "all" ]]; then
			        echo "Violation: The ingress setting is configured to ALL, which allows all requests including requests directly from the internet";
			    fi
			    echo $BLANK_LINE;
			fi
			
		done;

		if [[ $CSV != "True" ]]; then
			echo $BLANK_LINE;
		fi

	else
	    if [[ $CSV != "True" ]]; then
	    	echo "No Cloud Run Services found for Project $PROJECT_ID";
	    	echo $BLANK_LINE;
	    fi
	fi;

	sleep $SLEEP_SECONDS;
done;

