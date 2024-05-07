#!/bin/bash

# Function to display help menu
display_help() {
    cat << EOF
Usage: $0 [options]

Description:
  This script retrieves a list of project IDs from Google Cloud Platform using
  the 'gcloud' command-line tool.

Options:
  -h, --help    Display this help menu
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

# Retrieve list of project IDs from gcloud
gcloud projects list --format="value(PROJECT_ID)"
