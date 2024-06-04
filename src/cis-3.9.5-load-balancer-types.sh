#!/bin/bash

################################################################################
# CIS Google Cloud Computing Foundations Benchmark v2.0.0
# Rule 3.9.5: Ensure that the corrent type of load balancer is implemented
# Description: This script retrieves information about Google Cloud Platform
#              (GCP) load balancers. It parses this
#              information and outputs it in various formats, including CSV and
#              console output. The script also supports debugging mode for
#              detailed information and error logging.
# 
# Documentation: https://cloud.google.com/load-balancing/docs/forwarding-rule-concepts
#
# Debug: ./cis-3.9.5-load-balancer-types.sh -p gcp-aag-idog-uat -d
#
################################################################################

# Import common constants and functions
source common-constants.inc
source functions.inc

# Function to print debug information about projects
debug_projects() {
    if [[ $DEBUG == "True" ]]; then
        echo "DEBUG: Projects: $PROJECTS"
        echo "$BLANK_LINE"
    fi
}

# Function to print debug information about JSON data
debug_json() {
    local DATA_TYPE=$1
    local PROJECT_ID=$2
    local JSON_DATA=$3

    if [[ $DEBUG == "True" ]]; then
        echo "PROJECT: $PROJECT_ID:"
        echo "DEBUG: $DATA_TYPE (JSON):"
        echo "$(jq -C '.' <<< "$JSON_DATA")"
        echo "$BLANK_LINE"
    fi
}

# Function to print a message when no output is returned
function no_output_returned() {
    local MESSAGE=$1

    if [[ $CSV != "True" ]]; then
        echo "$MESSAGE"
        echo "$BLANK_LINE"
    fi
}

# Function to print the CSV header row
print_csv_header() {
    if [[ $CSV == "True" ]]; then
        # Print CSV header row
        echo "\"PROJECT_ID\",\"FORWARDING_RULE_NAME\",\"FORWARDING_RULE_DESCRIPTION\",\"FORWARDING_RULE_IP\",\"FORWARDING_RULE_IP_PROTOCOL\",\"FORWARDING_RULE_PORT_RANGE\",\"FORWARDING_RULE_TARGET\",\"FORWARDING_RULE_TARGET_TYPE\",\"FORWARDING_RULE_LOAD_BALANCING_SCHEME\""
    fi
}

output_forwarding_rule() {
    if [[ $CSV == "True" ]]; then
        print_csv_output
    else
        print_fixed_console_output
    fi
}

# Function to print CSV output
print_csv_output() {
    echo "\"$PROJECT_ID\",\"$FORWARDING_RULE_NAME\",\"$FORWARDING_RULE_DESCRIPTION\",\"$FORWARDING_RULE_IP\",\"$FORWARDING_RULE_IP_PROTOCOL\",\"$FORWARDING_RULE_PORT_RANGE\",\"$FORWARDING_RULE_TARGET\",\"$FORWARDING_RULE_TARGET_TYPE\",\"$FORWARDING_RULE_LOAD_BALANCING_SCHEME\""
}

# Function to print fixed console output
print_fixed_console_output() {
    echo "Project ID: $PROJECT_ID"
    echo "Forwarding Rule Name: $FORWARDING_RULE_NAME"
    echo "Forwarding Rule Description: $FORWARDING_RULE_DESCRIPTION"
    echo "Forwarding Rule IP: $FORWARDING_RULE_IP"
    echo "Forwarding Rule IP Protocol: $FORWARDING_RULE_IP_PROTOCOL"
    echo "Forwarding Rule Port Range: $FORWARDING_RULE_PORT_RANGE"
    echo "Forwarding Rule Target: $FORWARDING_RULE_TARGET"
    echo "Forwarding Rule Target Type: $FORWARDING_RULE_TARGET_TYPE"
    echo "Forwarding Rule Load Balancing Scheme: $FORWARDING_RULE_LOAD_BALANCING_SCHEME"
    echo "$BLANK_LINE"
}

# Function to get forwarding rules
function get_forwarding_rules() {
    local PROJECT_ID=$1

    # Get list of forwarding rules
    FORWARDING_RULES=$(gcloud compute forwarding-rules list --project $PROJECT_ID --quiet --format="json" 2>> "$ERROR_LOG_FILE" || echo "")

    echo "$FORWARDING_RULES"
}

# Function to parse forwarding rules
function parse_forwarding_rules() {
    local PROJECT_ID=$1
    local FORWARDING_RULES=$2

    if [[ $FORWARDING_RULES == "[]" ]]; then
        no_output_returned "No forwarding rules found for Project $PROJECT_ID."
    else
        # Loop through each forwarding rule
        echo "$FORWARDING_RULES" | jq -r -c '.[]' | while IFS='' read -r FORWARDING_RULE; do
            debug_json "Forwarding Rule" "$PROJECT_ID" "$FORWARDING_RULE"
            parse_forwarding_rule "$PROJECT_ID" "$FORWARDING_RULE"
            output_forwarding_rule
        done
    fi
}

# Function to parse a forwarding rule
function parse_forwarding_rule() {
    local PROJECT_ID=$1
    local FORWARDING_RULE=$2

    # Parse forwarding rule details
    FORWARDING_RULE_NAME=$(jq -r -c '.name // ""' <<< "$FORWARDING_RULE")
    FORWARDING_RULE_DESCRIPTION=$(jq -r -c '.description // ""' <<< "$FORWARDING_RULE")
    FORWARDING_RULE_IP=$(jq -r -c '.IPAddress // ""' <<< "$FORWARDING_RULE")
    FORWARDING_RULE_IP_PROTOCOL=$(jq -r -c '.IPProtocol // ""' <<< "$FORWARDING_RULE")
    FORWARDING_RULE_PORT_RANGE=$(jq -r -c '.portRange // ""' <<< "$FORWARDING_RULE")
    FORWARDING_RULE_TARGET=$(jq -r -c '.target // ""' <<< "$FORWARDING_RULE")
    FORWARDING_RULE_TARGET_TYPE=$(echo "$FORWARDING_RULE_TARGET" | awk -F'/' '{print $(NF-1)}')
    FORWARDING_RULE_LOAD_BALANCING_SCHEME=$(jq -r -c '.loadBalancingScheme // ""' <<< "$FORWARDING_RULE")
}

# Parse command-line arguments
declare DEBUG="False"
declare CSV="False"
declare PROJECT_ID=""
declare PROJECTS=""
declare HELP=$(cat << EOL
    $0 [-p, --project PROJECT] [-c, --csv] [-d, --debug] [-h, --help]
EOL
)

# Parse options and arguments using getopt
ARGS=$(getopt -o p:cdh --long project:,csv,debug,help -- "$@")

eval set -- "$ARGS"

while true; do
    case "$1" in
        -p|--project)
            PROJECT_ID="$2"
            shift 2
            ;;
        -c|--csv)
            CSV="True"
            shift
            ;;
        -d|--debug)
            DEBUG="True"
            shift
            ;;
        -h|--help)
            echo "$HELP"
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unknown option: $1"
            echo "$HELP"
            exit 1
            ;;
    esac
done

# Get list of projects
declare PROJECTS=$(get_projects "$PROJECT_ID")

# If no projects found, exit
if [[ $PROJECTS == "[]" ]]; then
    echo "No projects found"
    echo $BLANK_LINE
    exit 0
fi

# Print debug information about projects
debug_projects

# Print CSV header row
print_csv_header

# Loop through each project
for PROJECT_ID in $PROJECTS; do

    set_project "$PROJECT_ID"

    # Check if Compute Engine API is enabled
    if ! api_enabled compute.googleapis.com; then
        no_output_returned "Compute Engine API is not enabled for Project $PROJECT_ID."
        continue
    fi

    FORWARDING_RULES=$(get_forwarding_rules "$PROJECT_ID")
    debug_json "Forwarding Rules" "$PROJECT_ID" "$FORWARDING_RULES"
    parse_forwarding_rules "$PROJECT_ID" "$FORWARDING_RULES"
    sleep $SLEEP_SECONDS

done

# Delete error log file if empty
delete_empty_error_log "$ERROR_LOG_FILE"
