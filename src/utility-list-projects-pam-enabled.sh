#!/bin/bash

# =============================================================================
# Script Name: check-pam-api.sh
# Description: 
#   This script lists GCP projects and checks if the
#   privilegedaccessmanager.googleapis.com API is enabled in each respective project.
#
# Usage: 
#   ./check-pam-api.sh [-c, --csv] [-d, --debug] [-h, --help] 
#
# Arguments:
#   -c, --csv             Output results in CSV format.
#   -d, --debug           Enable debug mode to display API check output.
#   -h, --help            Display help information.
#
# Examples:
#   1. List all projects in CSV format:
#      ./check-pam-api.sh --csv
#
#   2. Enable debug mode:
#      ./check-pam-api.sh --debug
# =============================================================================

source common-constants.inc
source functions.inc

declare RESULTS=$(gcloud projects list --format="json")
declare DEBUG="False"
declare CSV="False"
declare HELP=$(cat << EOL
Usage: $0 [-c, --csv] [-d, --debug] [-h, --help]
  -c, --csv             Output results in CSV format.
  -d, --debug           Enable debug mode to display API check output.
  -h, --help            Display help information.

Examples:
  1. List all projects in CSV format:
     $0 --csv

  2. Enable debug mode:
     $0 --debug
EOL
)

# Parse long options and convert them to short options for compatibility
for arg in "$@"; do
  shift
  case "$arg" in
    "--help")          set -- "$@" "-h" ;;
    "--debug")         set -- "$@" "-d" ;;
    "--csv")           set -- "$@" "-c" ;;
    *)                 set -- "$@" "$arg" ;;
  esac
done

# Parse short options
while getopts "hdc" option; do
    case "${option}" in
        d) DEBUG="True" ;;
        c) CSV="True" ;;
        h)
            echo "$HELP"
            exit 0
            ;;
    esac
done

# Check if there are results
if [[ $RESULTS != "[]" ]]; then
    # Print CSV headers if CSV option is enabled
    if [[ $CSV == "True" ]]; then
        echo "\"PROJECT_ID\",\"PROJECT_NAME\",\"PAM_API_ENABLED\""
    fi

    # Iterate through each project
    echo "$RESULTS" | jq -rc '.[]' | while IFS='' read -r PROJECT; do
        PROJECT_ID=$(echo "$PROJECT" | jq -rc '.projectId')
        PROJECT_NAME=$(echo "$PROJECT" | jq -rc '.name')

        # Check if the privileged access manager API is enabled
        if gcloud services list --project="$PROJECT_ID" --format="value(config.name)" 2>/dev/null | \
           grep -q "^privilegedaccessmanager.googleapis.com$"; then
            PAM_API_ENABLED="true"
        else
            PAM_API_ENABLED="false"
        fi

        # Debug output if enabled
        if [[ $DEBUG == "True" ]]; then
            echo "[DEBUG] Project: $PROJECT_NAME ($PROJECT_ID), PAM API Enabled: $PAM_API_ENABLED"
        fi

        # Output results
        if [[ $CSV == "True" ]]; then
            echo "\"$PROJECT_ID\",\"$PROJECT_NAME\",\"$PAM_API_ENABLED\""
        else
            echo "Project ID: $PROJECT_ID"
            echo "Project Name: $PROJECT_NAME"
            echo "PAM API Enabled: $PAM_API_ENABLED"
            echo "$BLANK_LINE"
        fi
        sleep "$SLEEP_SECONDS"
    done
else
    echo "No projects found"
    echo "$BLANK_LINE"
fi
