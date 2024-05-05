#!/bin/bash

source functions.inc

PROJECT_IDS="";

print_help(){
    echo "Usage: $0 [OPTION]..."
    echo "Run all CIS audit scripts for each project."
    echo "Example: $0 -p project-12345 project-54321"
    echo 
    echo "Options:"
    echo "    -p, --project   projects to be audited; multiple projects are allowed; if no project provided, all projects will be audited"
    echo "    -h, --help	    display this help and exit"
}

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 		set -- "$@" "-h" ;;
    "--project")   	set -- "$@" "-p" ;;
    *)        		set -- "$@" "$arg"
  esac
done

while getopts "hdp:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_IDS=${OPTARG};;
        h)
        	print_help
        	exit 0;;
    esac;
done;

declare -a commands=("jq" "gcloud")
for cmd in "${commands[@]}"; do
    if ! command -v $cmd &> /dev/null
    then
        echo "$cmd could not be found on this host and is required to run the script. Please install the missing tool and try again."
        exit 1
    fi
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

FILENAME_PATTERN="(cis)-([0-9]{1,2}.[0-9]{1,2}.[0-9]{1,2})-([a-zA-Z/-]*)"
AUDIT_LOG_PREFIX=audit
AUDIT_SCRIPTS=$(ls | grep -E $FILENAME_PATTERN)


for PROJECT_ID in $PROJECT_IDS; do
    echo "---- Starting Audit for $PROJECT_ID ----"
    gcloud config set project $PROJECT_ID 2>/dev/null
    AUDIT_LOG="$AUDIT_LOG_PREFIX-$PROJECT_ID.log"

    for file in $AUDIT_SCRIPTS;
    do 
        echo "Running $file"
        echo $file | sed -E "s/$FILENAME_PATTERN\.(sh)/------CIS \2,\3------/" >> $AUDIT_LOG
        ./$file -p $PROJECT_ID >> $AUDIT_LOG
        echo "-----------------------------------------" >> $AUDIT_LOG
    done;
done;
