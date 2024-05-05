#!/bin/bash

source common-constants.inc;
source functions.inc;

declare SEPARATOR="---------------------------------------------------------------------------------"
declare PROJECT_IDS=""
declare DEBUG="False"
declare CSV="False"
declare HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-c, --csv] [-d, --debug] [-h, --help]
EOL
)

for arg in "$@"; do
  shift
  case "$arg" in
    "--help")        set -- "$@" "-h" ;;
    "--debug")       set -- "$@" "-d" ;;
    "--csv")         set -- "$@" "-c" ;;
    "--project")     set -- "$@" "-p" ;;
    *)               set -- "$@" "$arg"
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
        h)
            echo "$HELP"
            exit 0;;
    esac
done


if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects)
fi

if [[ $DEBUG == "True" ]]; then
    echo "Projects: $PROJECT_IDS"
    echo ""
fi

if [[ $CSV == "True" ]]; then
    echo "\"PROJECT_ID\",\"PROJECT_NAME\",\"PROJECT_OWNER\",\"PROJECT_APPLICATION\",\"INSTANCE_NAME\",\"IP_FORWARDING_ENABLED\",\"IP_FORWARDING_STATUS_MESSAGE\""
fi

for PROJECT_ID in $PROJECT_IDS; do

    set_project $PROJECT_ID

    if ! api_enabled compute.googleapis.com; then
        if [[ $CSV != "True" ]]; then
            echo "Compute Engine API is not enabled on Project $PROJECT_ID"
            echo ""
        fi
        continue
    fi

    #Get project details
    get_project_details $PROJECT_ID

    declare INSTANCES=$(gcloud compute instances list --quiet --format="json")

    if [[ $DEBUG == "True" ]]; then
        echo "Instances (JSON): $INSTANCES"
        echo ""
    fi

    if [[ $INSTANCES != "[]" ]]; then
        echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE; do
            if [[ $DEBUG == "True" ]]; then
                echo "Instance (JSON): $INSTANCE"
                echo ""
            fi

            INSTANCE_NAME=$(echo $INSTANCE | jq -rc '.name')
            IP_FORWARDING_ENABLED=$(echo $INSTANCE | jq -rc '.canIpForward' | tr '[:upper:]' '[:lower:]')

            if [[ $IP_FORWARDING_ENABLED == "true" ]]; then
                IP_FORWARDING_STATUS_MESSAGE="VIOLATION: IP forwarding enabled"

	    elif [[ -z $IP_FORWARDING_ENABLED || $IP_FORWARDING_ENABLED == "null" ]]; then
		    IP_FORWARDING_ENABLED="IP Forwarding is NOT explicitly configured"
		    IP_FORWARDING_STATUS_MESSAGE="N/A"
            else
                IP_FORWARDING_STATUS_MESSAGE="IP forwarding disabled"
            fi

            # Print the results gathered above
            if [[ $CSV != "True" ]]; then
                echo "Project ID: $PROJECT_ID"
                echo "Project Name: $PROJECT_NAME"
                echo "Project Application: $PROJECT_APPLICATION"
                echo "Project Owner: $PROJECT_OWNER"
                echo "Instance Name: $INSTANCE_NAME"
                echo "IP Forwarding Enabled: $IP_FORWARDING_ENABLED"
                echo "IP Forwarding Status: $IP_FORWARDING_STATUS_MESSAGE"
                echo ""
            else
                echo "\"$PROJECT_ID\",\"$PROJECT_NAME\",\"$PROJECT_OWNER\",\"$PROJECT_APPLICATION\",\"$INSTANCE_NAME\",\"$IP_FORWARDING_ENABLED\",\"$IP_FORWARDING_STATUS_MESSAGE\""
            fi
        done
        echo ""
    else
        if [[ $CSV != "True" ]]; then
            echo "No instances found for Project $PROJECT_ID"
            echo ""
        fi
    fi
    sleep $SLEEP_SECONDS;
done


