#!/bin/bash

source functions.inc;

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
            echo "\"$PROJECT_ID\", \"$PROJECT_APPLICATION\", \"$PROJECT_OWNER\" \"No Policy\"";
        else
            echo "No Cloud Armor Policies found for $PROJECT_ID";
            echo "";
        fi;
        return;
    fi;

    echo $CLOUD_ARMOR_POLICIES | jq -r -c '.[]' | while IFS='' read -r POLICY; do
        CLOUD_ARMOR_POLICY_NAME=$(echo $POLICY | jq -rc '.name');
        PROJECT_DETAILS=$(gcloud PROJECTS describe $PROJECT_ID --format="json");
        PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
        PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

        if [[ $CSV == "True" ]]; then
            echo "\"$PROJECT_ID\", \"$PROJECT_APPLICATION\", \"$PROJECT_OWNER\" \"$CLOUD_ARMOR_POLICY_NAME\"";
        else
            echo "PROJECT_ID: $PROJECT_ID";
            echo "PROJECT_APPLICATION: $PROJECT_APPLICATION";
            echo "PROJECT_OWNER: $PROJECT_OWNER";
	    echo "CLOUD_ARMOR_POLICY_NAME: $CLOUD_ARMOR_POLICY_NAME";
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
    echo "\"PROJECT_ID\", \"PROJECT_APPLICATION\", \"PROJECT_OWNER\" \"CLOUD_ARMOR_POLICY_NAME\"";
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

declare PROJECTS=$(get_projects);

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

    listCloudArmorPolicies;
done;


