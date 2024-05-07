#!/bin/bash

################################################################################
# Script Name: utility-list-projects.sh
# Description: This script retrieves a list of projects from Google Cloud
#              Platform using the 'gcloud' command-line tool and displays
#              relevant details for each project, such as name, application,
#              and owner. It also supports a delay between project outputs.
# Usage:       ./utility-list-projects.sh [options]
# Options:     -h, --help    Display this help menu
################################################################################

# Include common constants
source ./common-constants.inc

# Function to display help menu
display_help() {
    cat << EOF
Usage: $0 [options]

Description:
  This script retrieves a list of projects from Google Cloud Platform using the
  'gcloud' command-line tool and displays relevant details for each project,
  such as name, application, and owner. It also supports a delay between
  project outputs.

Options:
  -h, --help     Display this help menu
EOF
    exit 0
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            display_help
            ;;
        *)
            echo "Error: Unknown option '$1'"
            display_help
            ;;
    esac
done

# Get project list from gcloud
RESULTS=$(gcloud projects list --format="json")

# Check if there are any projects
if [[ $RESULTS != "[]" ]]; then
    # Process each project
    while IFS= read -r PROJECT; do
        # Extract project details
        NAME=$(jq -r '.name' <<< "$PROJECT")
        APPLICATION=$(jq -r '.labels.app' <<< "$PROJECT")
        OWNER=$(jq -r '.labels.adid' <<< "$PROJECT")

        # Output project details
        echo "Name: $NAME"
        [[ $APPLICATION != "null" ]] && echo "Application: $APPLICATION"
        [[ $OWNER != "null" ]] && echo "Owner: $OWNER"
        echo "" # Blank line between projects
        sleep "$SLEEP_SECONDS" # Introduce delay between projects
    done < <(jq -rc '.[]' <<< "$RESULTS")
else
    # No projects found
    echo "No projects found"
fi
