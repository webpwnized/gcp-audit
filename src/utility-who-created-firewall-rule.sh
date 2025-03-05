#!/bin/bash

# This script:
# 1. Validates the given GCP project and firewall rule.
# 2. Retrieves and prints project metadata and firewall details from direct gcloud commands.
# 3. Queries Cloud Logging for all matching firewall creation log entries and prints them all,
#    using user-defined freshness and method names if provided.
#
# Usage:
#   ./utility-who-created-firewall-rule.sh -p <PROJECT_ID> -f <FIREWALL_RULE_NAME> [options]
#
# Options:
#   -p, --project          The GCP project ID in which the firewall rule resides.
#   -f, --firewall-rule    The name of the firewall rule to investigate.
#   -c, --csv              Output results in CSV format.
#   -d, --debug            Enable debug output.
#   -F, --freshness        How far back in time to search logs (e.g. 400d, 48h). Default: 400d.
#   -m, --method-names     Comma-separated list of method names indicating firewall creation
#                          (e.g. "compute.firewalls.insert,v1.compute.firewalls.insert").
#                          Default: "compute.firewalls.insert,v1.compute.firewalls.insert"
#   -h, --help             Show this help message.
#
# Dependencies:
# - gcloud CLI configured
# - jq for JSON parsing
#
# Security:
# - This script relies on gcloud for authentication.
#
# Exit codes:
# - 0 on success
# - 1 if required parameters are missing or project/firewall doesn't exist
# - 2 if no creation logs found

source common-constants.inc
source functions.inc

PROJECT_NAME=""
FIREWALL_RULE_NAME=""
DEBUG="False"
CSV="False"
FRESHNESS="100d"
METHOD_NAMES="compute.firewalls.insert,v1.compute.firewalls.insert,beta.compute.firewalls.insert"

HELP=$(cat <<EOL
Usage: $0 -p <PROJECT_ID> -f <FIREWALL_RULE_NAME> [options]

Options:
  -p, --project          The GCP project ID in which the firewall rule resides.
  -f, --firewall-rule    The name of the firewall rule to investigate.
  -c, --csv              Output results in CSV format.
  -d, --debug            Enable debug output.
  -F, --freshness        How far back in time to search logs (e.g. 400d, 48h). Default: $FRESHNESS.
  -m, --method-names     Comma-separated list of method names indicating firewall creation.
                         Default: $METHOD_NAMES
  -h, --help             Show this help message.
EOL
)

# Parse long arguments first
for arg in "$@"; do
  shift
  case "$arg" in
    "--help")          set -- "$@" "-h" ;;
    "--debug")         set -- "$@" "-d" ;;
    "--csv")           set -- "$@" "-c" ;;
    "--project")       set -- "$@" "-p" ;;
    "--firewall-rule") set -- "$@" "-f" ;;
    "--freshness")     set -- "$@" "-F" ;;
    "--method-names")  set -- "$@" "-m" ;;
    *)                 set -- "$@" "$arg" ;;
  esac
done

while getopts "hdcp:f:F:m:" option; do
    case "${option}" in
        p)
            PROJECT_NAME="${OPTARG}";;
        f)
            FIREWALL_RULE_NAME="${OPTARG}";;
        d)
            DEBUG="True";;
        c)
            CSV="True";;
        F)
            FRESHNESS="${OPTARG}";;
        m)
            METHOD_NAMES="${OPTARG}";;
        h)
            echo "$HELP"
            exit 0;;
        *)
            echo "$HELP"
            exit 1;;
    esac
done

if [[ -z "$PROJECT_NAME" || -z "$FIREWALL_RULE_NAME" ]]; then
    echo "Error: Both project and firewall rule name must be provided."
    echo "$HELP"
    exit 1
fi

[ "$DEBUG" == "True" ] && echo "Debug: PROJECT_NAME=$PROJECT_NAME, FIREWALL_RULE_NAME=$FIREWALL_RULE_NAME, FRESHNESS=$FRESHNESS, METHOD_NAMES=$METHOD_NAMES"

# Validate the project
PROJECT_DATA=$(gcloud projects describe "$PROJECT_NAME" --format=json 2>/dev/null)
if [[ -z "$PROJECT_DATA" || "$PROJECT_DATA" == "null" ]]; then
    echo "Error: The project '$PROJECT_NAME' does not exist or you lack access."
    exit 1
fi

PROJECT_APPLICATION_ENTRY_CODE=$(echo "$PROJECT_DATA" | jq -rc '.labels.app // empty')
PROJECT_OWNER=$(echo "$PROJECT_DATA" | jq -rc '.labels.adid // empty')
PROJECT_ACC=$(echo "$PROJECT_DATA" | jq -rc '.labels.acc // empty')
PROJECT_DEPARTMENT_CODE=$(echo "$PROJECT_DATA" | jq -rc '.labels.dept // empty')
PROJECT_PAR=$(echo "$PROJECT_DATA" | jq -rc '.labels.par // empty')

# Validate the firewall rule
FIREWALL_DATA=$(gcloud compute firewall-rules describe "$FIREWALL_RULE_NAME" --project="$PROJECT_NAME" --format=json 2>/dev/null)
if [[ -z "$FIREWALL_DATA" || "$FIREWALL_DATA" == "null" ]]; then
    echo "Error: The firewall rule '$FIREWALL_RULE_NAME' does not exist in project '$PROJECT_NAME'."
    exit 1
fi

FW_NAME=$(echo "$FIREWALL_DATA" | jq -rc '.name')
FW_NETWORK=$(echo "$FIREWALL_DATA" | jq -rc '.network')
FW_DIRECTION=$(echo "$FIREWALL_DATA" | jq -rc '.direction')
FW_ALLOWED=$(echo "$FIREWALL_DATA" | jq -rc '.allowed')
FW_DENIED=$(echo "$FIREWALL_DATA" | jq -rc '.denied')
FW_SOURCERANGES=$(echo "$FIREWALL_DATA" | jq -rc '.sourceRanges')
FW_SOURCETAGS=$(echo "$FIREWALL_DATA" | jq -rc '.sourceTags')
FW_TARGETTAGS=$(echo "$FIREWALL_DATA" | jq -rc '.targetTags')
FW_CREATION_TIMESTAMP=$(echo "$FIREWALL_DATA" | jq -rc '.creationTimestamp')

# Extract just the network name from the full URL
FW_NETWORK_NAME=$(echo "$FW_NETWORK" | sed 's#.*/##')

# Construct the method name filter dynamically
METHOD_FILTER_PART=""
IFS=',' read -r -a METHODS <<< "$METHOD_NAMES"
for m in "${METHODS[@]}"; do
    if [[ -z "$METHOD_FILTER_PART" ]]; then
        METHOD_FILTER_PART="protoPayload.methodName=\"$m\""
    else
        METHOD_FILTER_PART="$METHOD_FILTER_PART OR protoPayload.methodName=\"$m\""
    fi
done
METHOD_FILTER_PART="($METHOD_FILTER_PART)"

FILTER="resource.type=\"gce_firewall_rule\" AND logName=\"projects/$PROJECT_NAME/logs/cloudaudit.googleapis.com%2Factivity\" AND $METHOD_FILTER_PART AND protoPayload.resourceName=\"projects/$PROJECT_NAME/global/firewalls/$FIREWALL_RULE_NAME\""
[ "$DEBUG" == "True" ] && echo "Debug: Running gcloud logging read with filter: $FILTER, freshness=$FRESHNESS"

LOG_RESULTS=$(gcloud logging read "$FILTER" --project="$PROJECT_NAME" --format=json --freshness="$FRESHNESS" 2>/dev/null)

if [[ -z "$LOG_RESULTS" || "$LOG_RESULTS" == "[]" ]]; then
    # No logs found
    if [[ $CSV == "True" ]]; then
        # Print header anyway if needed
        echo "\"PROJECT_NAME\",\"PROJECT_APPLICATION_ENTRY_CODE\",\"PROJECT_OWNER\",\"PROJECT_ACC\",\"PROJECT_DEPARTMENT_CODE\",\"PROJECT_PAR\",\"FIREWALL_RULE_NAME\",\"CREATOR\",\"LOCAL_TIMESTAMP\",\"CALLER_IP\",\"NETWORK\",\"DIRECTION\",\"ALLOWED\",\"DENIED\",\"SOURCE_RANGES\",\"SOURCE_TAGS\",\"TARGET_TAGS\",\"CREATION_TIMESTAMP\""
    fi
    exit 2
else
    # Process all entries
    SORTED_ENTRIES=$(echo "$LOG_RESULTS" | jq -rc 'sort_by(.timestamp) | .[]')

    # Print CSV header if CSV mode
    if [[ $CSV == "True" ]]; then
        echo "\"PROJECT_NAME\",\"PROJECT_APPLICATION_ENTRY_CODE\",\"PROJECT_OWNER\",\"PROJECT_ACC\",\"PROJECT_DEPARTMENT_CODE\",\"PROJECT_PAR\",\"FIREWALL_RULE_NAME\",\"CREATOR\",\"LOCAL_TIMESTAMP\",\"CALLER_IP\",\"NETWORK\",\"DIRECTION\",\"ALLOWED\",\"DENIED\",\"SOURCE_RANGES\",\"SOURCE_TAGS\",\"TARGET_TAGS\",\"CREATION_TIMESTAMP\""
    fi

    while IFS= read -r ENTRY; do
        [ "$DEBUG" == "True" ] && echo "Debug: ENTRY=$ENTRY"

        CREATOR=$(echo "$ENTRY" | jq -rc '.protoPayload.authenticationInfo.principalEmail // "UNKNOWN"')
        CALLER_IP=$(echo "$ENTRY" | jq -rc '.protoPayload.requestMetadata.callerIp // "UNKNOWN"')
        TIMESTAMP=$(echo "$ENTRY" | jq -rc '.timestamp')
        LOCAL_TIMESTAMP=$(date -d "$TIMESTAMP" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null)
        [ -z "$LOCAL_TIMESTAMP" ] && LOCAL_TIMESTAMP="$TIMESTAMP"

        if [[ $CSV == "True" ]]; then
            echo "\"$PROJECT_NAME\",\"$PROJECT_APPLICATION_ENTRY_CODE\",\"$PROJECT_OWNER\",\"$PROJECT_ACC\",\"$PROJECT_DEPARTMENT_CODE\",\"$PROJECT_PAR\",\"$FW_NAME\",\"$CREATOR\",\"$LOCAL_TIMESTAMP\",\"$CALLER_IP\",\"$FW_NETWORK_NAME\",\"$FW_DIRECTION\",\"$FW_ALLOWED\",\"$FW_DENIED\",\"$FW_SOURCERANGES\",\"$FW_SOURCETAGS\",\"$FW_TARGETTAGS\",\"$FW_CREATION_TIMESTAMP\""
        else
            echo "Project Name: $PROJECT_NAME"
            echo "Project Owner: $PROJECT_OWNER"
            echo "Project Application Entry Code: $PROJECT_APPLICATION_ENTRY_CODE"
            echo "Project ACC: $PROJECT_ACC"
            echo "Project Department Code: $PROJECT_DEPARTMENT_CODE"
            echo "Project PAR: $PROJECT_PAR"
            echo
            echo "Firewall Rule Name: $FW_NAME"
            echo "Creator: $CREATOR"
            echo "Timestamp (Local): $LOCAL_TIMESTAMP"
            echo "Caller IP: $CALLER_IP"
            echo "Firewall Creation Timestamp: $FW_CREATION_TIMESTAMP"
            echo
            echo "Firewall Rule Details:"
            echo "Network: $FW_NETWORK_NAME"
            echo "Direction: $FW_DIRECTION"
            echo "Allowed: $FW_ALLOWED"
            echo "Denied: $FW_DENIED"
            echo "Source Ranges: $FW_SOURCERANGES"
            echo "Source Tags: $FWSOURCETAGS"
            echo "Target Tags: $FW_TARGETTAGS"
            echo
        fi

    done <<< "$SORTED_ENTRIES"
fi

exit 0
