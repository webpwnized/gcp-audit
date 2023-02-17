#!/bin/bash

source helpers.inc

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
    echo $PROJECTS | jq -rc '.[]' | while IFS='' read PROJECT;do

	PROJECT_ID=$(echo $PROJECT | jq -r '.projectId');
		
	gcloud config set project $PROJECT_ID 2>/dev/null;
	
	if ! api_enabled compute.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "Compute Engine API is not enabled for Project $PROJECT_ID.";
		fi;
		continue;
	fi;
	
	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	if [[ $INSTANCES != "[]" ]]; then

		# Get the project details
		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');
				
		if [[ $CSV != "True" ]]; then
			echo "---------------------------------------------------------------------------------";
			echo "Instances for Project $PROJECT_ID";
			echo "---------------------------------------------------------------------------------";
		fi;
	
		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE; do

			INSTANCE_NAME=$(echo $INSTANCE | jq -rc '.name');			
			EXTERNAL_NETWORK_INTERFACES=$(echo $INSTANCE | jq -rc '.networkInterfaces' | jq 'select("accessConfigs")');
			IS_GKE_NODE=$(echo $INSTANCE | jq '.labels' | jq 'has("goog-gke-node")');
		
			echo $EXTERNAL_NETWORK_INTERFACES | jq -rc '.[]' | while IFS='' read -r INTERFACE;do

				HAS_IP_ADDRESS=$(echo $INTERFACE | jq -rc '.accessConfigs // empty');

				if [[ $HAS_IP_ADDRESS != "" ]]; then
					
					INTERFACE_NAME=$(echo $INTERFACE | jq -rc '.name');
					IP_ADDRESS=$(echo $INTERFACE | jq -rc '.accessConfigs[].natIP');
					NETWORK=$(echo $INTERFACE | jq -rc '.network' | awk -F/ '{print $(NF)}');
					SUBNETWORK=$(echo $INTERFACE | jq -rc '.subnetwork' | awk -F/ '{print $(NF)}');
					if [[ $IS_GKE_NODE == "false" ]]; then
						EXTERNAL_IP_STATUS_MESSAGE="VIOLATION: Exterally routable IP address detected";
					else
						EXTERNAL_IP_STATUS_MESSAGE="VIOLATION: GKE cluster is not a Private Kubernetes Cluster";
					fi;
						
					if [[ $CSV != "True" ]]; then
						echo "Project Name: $PROJECT_NAME";
						echo "Project Application: $PROJECT_APPLICATION";
						echo "Project Owner: $PROJECT_OWNER";
						echo "Instance Name: $INSTANCE_NAME";
						echo "Interface Name: $INTERFACE_NAME";
						echo "Network: $NETWORK";
						echo "Subnetwork: $SUBNETWORK";
						echo "IP Address: $IP_ADDRESS";
						echo "Status: $EXTERNAL_IP_STATUS_MESSAGE";
						echo "";
					else
						echo "$PROJECT_NAME, $PROJECT_APPLICATION, $PROJECT_OWNER, $INSTANCE_NAME, $NETWORK, $SUBNETWORK, $INTERFACE_NAME, $IP_ADDRESS, $IS_GKE_NODE, \"$EXTERNAL_IP_STATUS_MESSAGE\"";
					fi;
				else
					if [[ $CSV != "True" ]]; then
						echo "Non-issue: The instance does not have an external network interface";
						echo "";
					fi;
				fi;
			done;
		done;
	else
		if [[ $CSV != "True" ]]; then
			echo "No compute instances found for Project $PROJECT_ID";
			echo "";
		fi;
	fi;
	sleep 0.5;
    done;
else
	if [[ $CSV != "True" ]]; then
    		echo "No projects found";
    		echo "";
	fi;
fi;

