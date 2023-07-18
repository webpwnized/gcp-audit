#!/bin/bash

source functions.inc;

function hasHTTPLoadBalancer() {

	local HTTP_LOAD_BALANCERS=$(gcloud compute target-http-proxies list --quiet --format="json");
	local HTTPS_LOAD_BALANCERS=$(gcloud compute target-https-proxies list --quiet --format="json");
	local TRUE=1;
	local FALSE=0;
	
	if [[ $HTTP_LOAD_BALANCERS == "[]" ]]; then
		if [[ $HTTPS_LOAD_BALANCERS == "[]" ]]; then
			VALUE=$FALSE;
		else
			VALUE=$TRUE;
		fi;
	else
		VALUE=$TRUE;
	fi;
	echo "$VALUE";
	# TODO: Return value not working for unknown reason
	#return "$VALUE";
}

function listCloudArmorPolicies() {
	# Variables are global scope if they are not preceeded by the local keyword
	PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
	PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
	PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');
	CLOUD_ARMOR_POLICIES=$(gcloud compute security-policies list --format="json");
	
	if [[ $DEBUG == "True" ]]; then
		debugCloudArmorPolicies;
	fi;

	if [[ $CLOUD_ARMOR_POLICIES == "[]" ]]; then
		if [[ $CSV == "True" ]]; then
		    echo "\"$PROJECT_ID\", \"$PROJECT_APPLICATION\", \"$PROJECT_OWNER\" \"No Policy\",\"\",\"\",\"\"";
		else
		    echo "No Cloud Armor policies found for project $PROJECT_ID";
		    echo "";
		fi;
		return;
	fi;

	echo $CLOUD_ARMOR_POLICIES | jq -r -c '.[]' | while IFS='' read -r POLICY; do
	
		CLOUD_ARMOR_POLICY_NAME=$(echo $POLICY | jq -rc '.name');
		CLOUD_ARMOR_POLICY_DDOS_PROTECTION_ENABLED=$(echo $POLICY | jq -rc '.adaptiveProtectionConfig.layer7DdosDefenseConfig.enable');
		CLOUD_ARMOR_POLICY_RULES=$(echo $POLICY | jq -rc '.rules');
	
		if [[ $CSV == "True" ]]; then
			echo $CLOUD_ARMOR_POLICY_RULES | jq -r -c '.[]' | while IFS='' read -r RULE; do
			    	RULE_ACTION=$(echo $RULE | jq -rc '.action');
			    	RULE_DESCRIPTION=$(echo $RULE | jq -rc '.description');
			    	RULE_MATCH=$(echo $RULE | jq -rc '.match');
				echo "\"$PROJECT_ID\", \"$PROJECT_APPLICATION\", \"$PROJECT_OWNER\" \"$CLOUD_ARMOR_POLICY_NAME\",\"$RULE_DESCRIPTION\",\"$RULE_ACTION\",\"$RULE_MATCH\"";
			done;
		else
		    echo "Project: $PROJECT_ID";
		    echo "Application: $PROJECT_APPLICATION";
		    echo "Owner: $PROJECT_OWNER";
		    echo "Cloud Armor Policy Name: $CLOUD_ARMOR_POLICY_NAME";
		    echo $CLOUD_ARMOR_POLICY_RULES | jq -r -c '.[]' | while IFS='' read -r RULE; do
		    	RULE_ACTION=$(echo $RULE | jq -rc '.action');
		    	RULE_DESCRIPTION=$(echo $RULE | jq -rc '.description');
		    	RULE_MATCH=$(echo $RULE | jq -rc '.match');
		    	echo "";
		    	echo "Rule Description: $RULE_DESCRIPTION";
		    	echo "Rule Action: $RULE_ACTION";
		    	echo "Rule Match: $RULE_MATCH";
		    done;
		    echo "";
		fi;
	done;
}

function debugCloudArmorPolicies() {
	echo "Cloud Armor Policies (JSON): $CLOUD_ARMOR_POLICIES";
	echo "";
}

function debugProjects() {
	echo "Projects (JSON): $PROJECTS";
	echo "";
}

function printCSVHeaderRow() {
	echo "\"PROJECT_ID\", \"PROJECT_APPLICATION\", \"PROJECT_OWNER\" \"CLOUD_ARMOR_POLICY_NAME\",\"RULE_DESCRIPTION\",\"RULE_ACTION\",\"RULE_MATCH\"";
}

declare DEBUG="False";
declare CSV="False";
declare PROJECT_ID="";
declare PROJECTS="";
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

while getopts "hdcip:" option; do 
    case "${option}" in
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

declare PROJECTS=$(get_projects "$PROJECT_ID");

if [[ $PROJECTS == "[]" ]]; then
    echo "No projects found";
    echo "";
    exit 0;
fi;

if [[ $DEBUG == "True" ]]; then
	debugProjects;
fi;

if [[ $CSV == "True" ]]; then
    printCSVHeaderRow;
fi;

for PROJECT_ID in $PROJECTS; do

	set_project $PROJECT_ID;

	if ! api_enabled compute.googleapis.com; then
		if [[ $CSV != "True" ]]; then
		    echo "Compute Engine API is not enabled for Project $PROJECT_ID.";
		fi;
		continue;
	fi;

	if [[ "$(hasHTTPLoadBalancer)" == "0" ]]; then
		if [[ $CSV != "True" ]]; then
		    echo "No HTTP Load Balancers found for project $PROJECT_ID";
		    echo "";
		fi;
		continue;
	fi;

	listCloudArmorPolicies;
done;


