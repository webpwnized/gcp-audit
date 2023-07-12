#!/bin/bash

source functions.inc

declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare ICH="False";
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

while getopts "hdcip:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_ID=${OPTARG};;
        d)
        	DEBUG="True";;
        c)
        	CSV="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;

if [[ $PROJECT_ID == "" ]]; then
    declare PROJECTS=$(gcloud projects list --format="json");
else
    declare PROJECTS=$(gcloud projects list --format="json" --filter="name:$PROJECT_ID");
fi;

if [[ $PROJECTS != "[]" ]]; then

    if [[ $CSV == "True" ]]; then
	    echo "\"PROJECT_NAME\", \"PROJECT_APPLICATION\", \"PROJECT_OWNER\", \"IP_ADDRESS\", \"ADDRESS_TYPE\", \"KIND\", \"ADDRESS_NAME\", \"PURPOSE\", \"DESCRIPTION\", \"STATUS\", \"VERSION\", \"DIRTY\", \"EXTERNAL_IP_STATUS_MESSAGE\"";
    fi;

    echo $PROJECTS | jq -rc '.[]' | while IFS='' read PROJECT;do

	PROJECT_ID=$(echo $PROJECT | jq -r '.projectId');
		
	set_project $PROJECT_ID;
	
	if ! api_enabled compute.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "Compute Engine API is not enabled for Project $PROJECT_ID.";
		fi;
		continue;
	fi;
	
	declare ADDRESSES=$(gcloud compute addresses list --quiet --format="json");

	if [[ $ADDRESSES != "[]" ]]; then

		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

		if [[ $CSV != "True" ]]; then
			echo "---------------------------------------------------------------------------------";
			echo "External IP Addresses for Project $PROJECT_ID";
			echo "---------------------------------------------------------------------------------";
		fi;
		
		echo $ADDRESSES | jq -rc '.[]' | while IFS='' read -r ADDRESS;do
		
			if [[ $DEBUG == "True" ]]; then
				echo $ADDRESS | jq -rc '.';
			fi;

			ADDRESS_NAME=$(echo $ADDRESS | jq -rc '.name');
			IP_ADDRESS=$(echo $ADDRESS | jq -rc '.address');
			ADDRESS_TYPE=$(echo $ADDRESS | jq -rc '.addressType');
			KIND=$(echo $ADDRESS | jq -rc '.kind');
			STATUS=$(echo $ADDRESS | jq -rc '.status');
			DESCRIPTION=$(echo $ADDRESS | jq -rc '.description //empty');
			VERSION=$(echo $ADDRESS | jq -rc '.ipVersion // empty');
			PURPOSE=$(echo $ADDRESS | jq -rc '.purpose // empty');
			USERS=$(echo $ADDRESS | jq -rc '.users[]?');
			
			# Set the Purpose field to a better value
			if [[ $PURPOSE == "" ]]; then
				if [[ $USERS == *"forwardingRules"* ]]; then
					PURPOSE="Forwarding Rule";
				elif [[ $USERS == *"routers"* ]]; then
					PURPOSE="Cloud NAT Router";
				elif [[ $STATUS == "RESERVED" ]]; then
					PURPOSE="Reserved";
				fi;
			elif [[ $PURPOSE == "NAT_AUTO" ]]; then
				PURPOSE="Cloud NAT Router";
			fi;
			
			# Decide if the IP address is dirty
			if [[ $PURPOSE == "Cloud NAT Router" ]]; then
				DIRTY="False";
				EXTERNAL_IP_STATUS_MESSAGE="Non-issue: The IP address belongs to a Cloud NAT Router";
			elif [[ $PURPOSE == "Forwarding Rule" ]]; then
				DIRTY="False";
				EXTERNAL_IP_STATUS_MESSAGE="Non-issue: The IP address belongs to a Load Balancer Forwarding Rule";
			elif [[ $PURPOSE == "Reserved" ]]; then
				DIRTY="True";
				EXTERNAL_IP_STATUS_MESSAGE="WARNING: The IP address is external but not in use at this time";
			elif [[ $ADDRESS_TYPE == "EXTERNAL" ]]; then
				DIRTY="True";
				EXTERNAL_IP_STATUS_MESSAGE="VIOLATION: Exterally routable IP address detected";
			else
				DIRTY="False";
				EXTERNAL_IP_STATUS_MESSAGE="Non-issue: The IP address cannot be routed externally";
			fi;
			
			# Right now, we only print dirty addresses, but we could add a flag to print all
			if [[ $CSV != "True" && $DIRTY == "True" ]]; then
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";
				echo "IP Address: $IP_ADDRESS ($ADDRESS_TYPE $KIND)";
				echo "Name: $ADDRESS_NAME";
				echo "Status: $STATUS";
				echo "Purpose: $PURPOSE";
				echo "Description: $DESCRIPTION";
				echo "Version: $VERSION";
				echo "$EXTERNAL_IP_STATUS_MESSAGE";
				echo "";
			elif [[ $CSV == "True" && $DIRTY == "True" ]]; then
				echo "\"$PROJECT_NAME\", \"$PROJECT_APPLICATION\", \"$PROJECT_OWNER\", \"$IP_ADDRESS\", \"$ADDRESS_TYPE\", \"$KIND\", \"$ADDRESS_NAME\", \"$PURPOSE\", \"$DESCRIPTION\", \"$STATUS\", \"$VERSION\", \"$DIRTY\", \"$EXTERNAL_IP_STATUS_MESSAGE\"";
			fi;
		done;
	fi;
	sleep 0.5;
    done;
else
	if [[ $CSV != "True" ]]; then
    		echo "No projects found";
    		echo "";
	fi;
fi;

