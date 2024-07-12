#!/bin/bash

source common-constants.inc;
source functions.inc

declare SEPARATOR="---------------------------------------------------------------------------------";
declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
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

while getopts "hdcp:" option
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
        	echo $HELP; 
        	exit 0;;
    esac;
done;


if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

if [[ $DEBUG == "True" ]]; then
	echo "Projects: $PROJECT_IDS";
fi;

if [[ $CSV == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"CLUSTER_NAME\", \"CLUSTER_NODE_VERSION\", \"BINARY_AUTHORIZATION_MODE\", \"DATABASE_ENCRYPTION_MODE\", \"PRIVATE_CLUSTER_MODE\"";
fi;

for PROJECT_ID in $PROJECT_IDS; do

	set_project $PROJECT_ID;

	if ! api_enabled container.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "GKE Cluster API is not enabled on Project $PROJECT_ID";
			continue;
		fi;
	fi;

	declare CLUSTERS=$(gcloud container clusters list --quiet --format="json");

	if [[ $DEBUG == "True" ]]; then
		echo "GKE Clusters (JSON): $CLUSTERS";
	fi;

	if [[ $CSV != "True" ]]; then
		echo $SEPARATOR;
		echo "GKE Clusters for Project $PROJECT_ID";
		echo $SEPARATOR;
		echo $BLANK_LINE;
	fi;
	
	if [[ $CLUSTERS != "[]" ]]; then

      		#Get project details
      		get_project_details $PROJECT_ID

		echo $CLUSTERS | jq -rc '.[]' | while IFS='' read -r CLUSTER;do

			CLUSTER_NAME=$(echo $CLUSTER | jq -rc '.name');
			CLUSTER_CONTROLLER_VERSION=$(echo $CLUSTER | jq -rc '.currentMasterVersion');
			CLUSTER_NODE_VERSION=$(echo $CLUSTER | jq -rc '.currentNodeVersion');
			NODE_COUNT=$(echo $CLUSTER | jq -rc '.currentNodeCount');
			BINARY_AUTHORIZATION_MODE=$(echo $CLUSTER | jq -rc '.binaryAuthorization.evaluationMode // empty');
			DATABASE_ENCRYPTION_MODE=$(echo $CLUSTER | jq -rc '.databaseEncryption.state // empty');
			PRIVATE_CLUSTER_MODE=$(echo $CLUSTER | jq -rc '.privateClusterConfig.enablePrivateNodes // empty');

			# Print the results gathered above
			if [[ $CSV != "True" ]]; then
				echo "Project ID: $PROJECT_ID";
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";
				echo "GKE Cluster Name: $CLUSTER_NAME";
				echo "GKE Cluster Node Version: $CLUSTER_NODE_VERSION";
				echo "GKE Cluster Binary Authorization Status: $BINARY_AUTHORIZATION_MODE";
				echo "GKE Cluster Database Encryption Mode: $DATABASE_ENCRYPTION_MODE";
				echo "GKE Cluster Private Cluster Mode: $PRIVATE_CLUSTER_MODE";				
				echo $BLANK_LINE;
			else
				echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$CLUSTER_NAME\", \"$CLUSTER_NODE_VERSION\", \"$BINARY_AUTHORIZATION_MODE\", \"$DATABASE_ENCRYPTION_MODE\", \"$PRIVATE_CLUSTER_MODE\"";
			fi;		

		done;
	else
		if [[ $CSV != "True" ]]; then
			echo "No GKE Clusters found for project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
	fi;
	sleep $SLEEP_SECONDS;
done;

