#!/bin/bash

source functions.inc

declare RESULTS=$(gcloud projects list --format="json");

declare DEBUG="False";
declare CSV="False";
declare OWNER_ONLY="False";
declare HELP=$(cat << EOL
	$0 [-c, --csv] [-d, --debug] [-h, --help] [-o, --owner-only]
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help")        set -- "$@" "-h" ;;
    "--debug")       set -- "$@" "-d" ;;
    "--csv")         set -- "$@" "-c" ;;
    "--owner-only")  set -- "$@" "-o" ;;
    *)               set -- "$@" "$arg"
  esac
done

while getopts "hdco" option
do 
    case "${option}"
        in
        d)
            DEBUG="True";;
        c)
            CSV="True";;
        o)
            OWNER_ONLY="True";;
        h)
            echo "$HELP"; 
            exit 0;;
    esac;
done;

if [[ $RESULTS != "[]" ]]; then
    if [[ $CSV == "True" ]]; then
        if [[ $OWNER_ONLY == "True" ]]; then
            echo "\"PROJECT_OWNER\"";
        else
            echo "\"PROJECT_NAME\",\"PROJECT_APPLICATION_ENTRY_CODE\",\"PROJECT_OWNER\",\"PROJECT_ACC\", \"PROJECT_DEPARTMENT_CODE\", \"PROJECT_PAR\"";
        fi;
    fi;
        
    echo $RESULTS | jq -rc '.[]' | while IFS='' read PROJECT; do
        PROJECT_NAME=$(echo $PROJECT | jq -rc '.name');
        PROJECT_APPLICATION_ENTRY_CODE=$(echo $PROJECT | jq -rc '.labels.app');
        PROJECT_OWNER=$(echo $PROJECT | jq -rc '.labels.adid');
        PROJECT_ACC=$(echo $PROJECT | jq -rc '.labels.acc');
        PROJECT_DEPARTMENT_CODE=$(echo $PROJECT | jq -rc '.labels.dept');
        PROJECT_PAR=$(echo $PROJECT | jq -rc '.labels.par');

        if [[ $DEBUG == "True" ]]; then
            echo -n "Lables (JSON): ";
            echo $PROJECT | jq -rc '.labels'; 
        fi;

        if [[ $CSV == "True" ]]; then
            if [[ $OWNER_ONLY == "True" ]]; then
                echo "\"$PROJECT_OWNER\"";
            else
                echo "\"$PROJECT_NAME\",\"$PROJECT_APPLICATION_ENTRY_CODE\",\"$PROJECT_OWNER\",\"$PROJECT_ACC\", \"$PROJECT_DEPARTMENT_CODE\", \"$PROJECT_PAR\"";
            fi;
        else
            if [[ $OWNER_ONLY == "True" ]]; then
                echo "$PROJECT_OWNER";
            else
                echo "Project Name: $PROJECT_NAME";
                echo "Project Owner: $PROJECT_OWNER";
                echo "Project Application Entry Code: $PROJECT_APPLICATION_ENTRY_CODE";
                echo "Project ACC: $PROJECT_ACC";
                echo "Project Department Code: $PROJECT_DEPARTMENT_CODE";
                echo "Project PAR: $PROJECT_PAR";
                echo "";
            fi;
        fi;
    done
else
    echo "No projects found";
    echo "";
fi;


