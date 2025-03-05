#!/bin/bash

# =============================================================================
# Script Name: list-projects.sh
# Description: 
#   This script lists GCP projects with optional filters and output formats.
#   Supports CSV output, debug mode, owner-only output, and filtering by owner.
#
# Usage: 
#   ./list-projects.sh [-c, --csv] [-d, --debug] [-h, --help] 
#                      [-o, --owner-only] [-fo, --filter-owners <adid1,adid2,...>]
#
# Arguments:
#   -c, --csv             Output results in CSV format.
#   -d, --debug           Enable debug mode to display project labels.
#   -h, --help            Display help information.
#   -o, --owner-only      Output only the project owner information.
#   -fo, --filter-owners  Filter projects by a comma-separated list of owners (adid).
#
# Examples:
#   1. List all projects in CSV format:
#      ./list-projects.sh --csv
#
#   2. Display only project owners:
#      ./list-projects.sh --owner-only
#
#   3. Enable debug mode:
#      ./list-projects.sh --debug
#
#   4. Filter projects by specific owners:
#      ./list-projects.sh --filter-owners owner1,owner2
#
#   5. Combine CSV output and owner filter:
#      ./list-projects.sh --csv --filter-owners owner1,owner2
#
# =============================================================================

source common-constants.inc
source functions.inc

declare RESULTS=$(gcloud projects list --format="json");
declare DEBUG="False";
declare CSV="False";
declare OWNER_ONLY="False";
declare FILTER_OWNERS="";
declare HELP=$(cat << EOL
Usage: $0 [-c, --csv] [-d, --debug] [-h, --help] [-o, --owner-only] [-fo, --filter-owners <adid1,adid2,...>]
  -c, --csv             Output results in CSV format.
  -d, --debug           Enable debug mode to display project labels.
  -h, --help            Display help information.
  -o, --owner-only      Output only the project owner information.
  -fo, --filter-owners  Filter projects by a comma-separated list of owners (adid).

Examples:
  1. List all projects in CSV format:
     $0 --csv

  2. Display only project owners:
     $0 --owner-only

  3. Enable debug mode:
     $0 --debug

  4. Filter projects by specific owners:
     $0 --filter-owners owner1,owner2

  5. Combine CSV output and owner filter:
     $0 --csv --filter-owners owner1,owner2
EOL
);

# Parse long options and convert them to short options for compatibility
for arg in "$@"; do
  shift
  case "$arg" in
    "--help")            set -- "$@" "-h" ;;
    "--debug")           set -- "$@" "-d" ;;
    "--csv")             set -- "$@" "-c" ;;
    "--owner-only")      set -- "$@" "-o" ;;
    "--filter-owners")   set -- "$@" "-f" ;;
    *)                   set -- "$@" "$arg" ;;
  esac
done

# Parse short options
while getopts "hdcof:" option; do
    case "${option}" in
        d) DEBUG="True" ;;
        c) CSV="True" ;;
        o) OWNER_ONLY="True" ;;
        f) FILTER_OWNERS="${OPTARG}" ;;
        h) 
            echo "$HELP"
            exit 0
            ;;
    esac
done

# Function to check if a value is in a comma-separated list
is_in_list() {
    local value=$1
    local list=$2
    [[ ",$list," =~ ",$value," ]]
}

# Check if there are results
if [[ $RESULTS != "[]" ]]; then
    # Print CSV headers if CSV option is enabled
    if [[ $CSV == "True" ]]; then
        if [[ $OWNER_ONLY == "True" ]]; then
            echo "\"PROJECT_OWNER\""
        else
            echo "\"PROJECT_NAME\",\"PROJECT_APPLICATION_ENTRY_CODE\",\"PROJECT_OWNER\",\"PROJECT_ACC\",\"PROJECT_DEPARTMENT_CODE\",\"PROJECT_PAR\""
        fi
    fi

    # Iterate through each project
    echo "$RESULTS" | jq -rc '.[]' | while IFS='' read -r PROJECT; do
        PROJECT_NAME=$(echo "$PROJECT" | jq -rc '.name')
        PROJECT_APPLICATION_ENTRY_CODE=$(echo "$PROJECT" | jq -rc '.labels.app')
        PROJECT_OWNER=$(echo "$PROJECT" | jq -rc '.labels.adid')
        PROJECT_ACC=$(echo "$PROJECT" | jq -rc '.labels.acc')
        PROJECT_DEPARTMENT_CODE=$(echo "$PROJECT" | jq -rc '.labels.dept')
        PROJECT_PAR=$(echo "$PROJECT" | jq -rc '.labels.par')

        # Debug output if enabled
        if [[ $DEBUG == "True" ]]; then
            echo -n "Labels (JSON): "
            echo "$PROJECT" | jq -rc '.labels'
        fi

        # Filter by owners if FILTER_OWNERS is set
        if [[ -n $FILTER_OWNERS ]] && ! is_in_list "$PROJECT_OWNER" "$FILTER_OWNERS"; then
            continue  # Skip projects not in the filter list
        fi

        # CSV Output
        if [[ $CSV == "True" ]]; then
            if [[ $OWNER_ONLY == "True" ]]; then
                echo "\"$PROJECT_OWNER\""
            else
                echo "\"$PROJECT_NAME\",\"$PROJECT_APPLICATION_ENTRY_CODE\",\"$PROJECT_OWNER\",\"$PROJECT_ACC\",\"$PROJECT_DEPARTMENT_CODE\",\"$PROJECT_PAR\""
            fi
        else
            # Standard Output
            if [[ $OWNER_ONLY == "True" ]]; then
                echo "$PROJECT_OWNER"
            else
                echo "Project Name: $PROJECT_NAME"
                echo "Project Owner: $PROJECT_OWNER"
                echo "Project Application Entry Code: $PROJECT_APPLICATION_ENTRY_CODE"
                echo "Project ACC: $PROJECT_ACC"
                echo "Project Department Code: $PROJECT_DEPARTMENT_CODE"
                echo "Project PAR: $PROJECT_PAR"
                echo "$BLANK_LINE"
            fi
        fi
        sleep "$SLEEP_SECONDS"
    done
else
    echo "No projects found"
    echo "$BLANK_LINE"
fi
