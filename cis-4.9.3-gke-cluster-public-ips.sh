#!/bin/bash

source common-constants.inc;
source functions.inc;

# Reference: 
# https://cloud.google.com/sdk/gcloud/reference/container/clusters/list

function output_header() {
	if [[ $CSV == "True" ]]; then
		output_csv_header;
	fi;
};

function output_csv_header() {
	echo "\"PROJECT_NAME\", \"PROJECT_APPLICATION\", \"PROJECT_OWNER\", \"CLUSTER_NAME\", \"CLUSTER_STATUS\", \"CLUSTER_NETWORK\", \"CLUSTER_SUBNETWORK\", \"CLUSTER_AUTHORIZED_NETWORKS\", \"CLUSTER_PUBLIC_ENDPOINT\", \"CLUSTER_PUBLIC_ENDPOINT_FLAG\"";
};

function output_gke_cluster_csv() {
	echo "\"$PROJECT_NAME\", \"$PROJECT_APPLICATION\", \"$PROJECT_OWNER\", \"$CLUSTER_NAME\", \"$CLUSTER_STATUS\", \"$CLUSTER_NETWORK\", \"$CLUSTER_SUBNETWORK\", \"$CLUSTER_AUTHORIZED_NETWORKS\", \"$CLUSTER_PUBLIC_ENDPOINT\", \"$CLUSTER_PUBLIC_ENDPOINT_FLAG\"";
};

function output_gke_cluster() {
	if [[ $CSV == "True" ]]; then
		output_gke_cluster_csv;
	else
		output_gke_cluster_text;
	fi;
};

function output_gke_cluster_text() {
	echo "Project Name: $PROJECT_NAME";
	echo "Project Application: $PROJECT_APPLICATION";
	echo "Project Owner: $PROJECT_OWNER";
	echo "Cluster Name: $CLUSTER_NAME";
	echo "Cluster Status: $CLUSTER_STATUS";
	echo "Cluster Network: $CLUSTER_NETWORK";
	echo "Cluster Subnetwork: $CLUSTER_SUBNETWORK";
	echo "Cluster Autorized Networks: $CLUSTER_AUTHORIZED_NETWORKS";
	echo "Cluster Control Plane External IP Address: $CLUSTER_PUBLIC_ENDPOINT";
	echo $BLANK_LINE;
};

function parse_gke_cluster() {
	local l_CLUSTER=$1;

	CLUSTER_NAME=$(echo $l_CLUSTER | jq -rc '.name');
	CLUSTER_STATUS=$(echo $l_CLUSTER | jq -rc '.status');
	CLUSTER_SUBNETWORK=$(echo $l_CLUSTER | jq -rc '.subnetwork');
	CLUSTER_NETWORK=$(echo $l_CLUSTER | jq -rc '.network');
	CLUSTER_PUBLIC_ENDPOINT=$(echo $l_CLUSTER | jq -rc '.privateClusterConfig.publicEndpoint // empty');
	CLUSTER_AUTHORIZED_NETWORKS=$(echo $l_CLUSTER | jq -rc 'if (.masterAuthorizedNetworksConfig.cidrBlocks | length) > 0 then .masterAuthorizedNetworksConfig.cidrBlocks | map(.cidrBlock) | join(" ") else empty end');
	
	CLUSTER_PUBLIC_ENDPOINT_FLAG="False";
	if [[ $CLUSTER_PUBLIC_ENDPOINT != "" ]]; then
		CLUSTER_PUBLIC_ENDPOINT_FLAG="True";
	fi;
};

source ./standard-menu.inc;

if [[ $PROJECT_ID == "" ]]; then
    declare PROJECTS=$(gcloud projects list --format="json");
else
    declare PROJECTS=$(gcloud projects list --format="json" --filter="name:$PROJECT_ID");
fi;

if [[ $DEBUG == "True" ]]; then
	echo "Projects: $PROJECTS";
	echo $BLANK_LINE;
fi;

if [[ $PROJECTS != "[]" ]]; then

	output_header;
		
	echo $PROJECTS | jq -rc '.[]' | while IFS='' read PROJECT;do

		PROJECT_ID=$(echo $PROJECT | jq -r '.projectId');
		
		set_project $PROJECT_ID;
	
		if ! api_enabled container.googleapis.com; then
			if [[ $CSV != "True" ]]; then
				echo "Container API is not enabled for Project $PROJECT_ID.";
			fi;
			continue;
		fi;
		
		declare CLUSTERS=$(gcloud container clusters list --quiet --format="json" 2>/dev/null);

		if [[ $DEBUG == "True" ]]; then
			echo "Clusters (JSON): $CLUSTERS";
			echo $BLANK_LINE;
		fi;

		if [[ $CLUSTERS != "[]" ]]; then

			#Get project details
      			get_project_details $PROJECT_ID;
      		
			echo $CLUSTERS | jq -rc '.[]' | while IFS='' read CLUSTER;do
				
				if [[ $DEBUG == "True" ]]; then
					echo "Cluster (JSON): $CLUSTER";
					echo $BLANK_LINE;
				fi;

				parse_gke_cluster "$CLUSTER";				
				output_gke_cluster;
			done;
		else
			if [[ $CSV == "False" ]]; then
				echo "No clusters found";
				echo $BLANK_LINE;
			fi;
		fi;
		
		sleep $SLEEP_SECONDS;
	done;
else
	if [[ $CSV == "False" ]]; then
		echo "No projects found";
		echo $BLANK_LINE;
	fi;
fi;

