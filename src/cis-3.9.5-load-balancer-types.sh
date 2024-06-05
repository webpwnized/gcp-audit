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

# Function to print the CSV header row
print_csv_header() {
    if [[ $CSV == "True" ]]; then
        # Print CSV header row
        echo "\"PROJECT_ID\",\"PROJECT_NAME\",\"PROJECT_APPLICATION\",\"PROJECT_OWNER\",\"FORWARDING_RULE_NAME\",\"FORWARDING_RULE_DESCRIPTION\",\"FORWARDING_RULE_LOAD_BALANCER_TYPE\",\"FORWARDING_RULE_TARGET_TYPE\",\"FORWARDING_RULE_LOAD_BALANCING_SCHEME\",\"FORWARDING_RULE_IP_PROTOCOL\",\"FORWARDING_RULE_IP\",\"FORWARDING_RULE_PORT_RANGE\""
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
    echo "\"$PROJECT_ID\",\"$PROJECT_NAME\",\"$PROJECT_APPLICATION\",\"$PROJECT_OWNER\",\"$FORWARDING_RULE_NAME\",\"$FORWARDING_RULE_DESCRIPTION\",\"$FORWARDING_RULE_LOAD_BALANCER_TYPE\",\"$FORWARDING_RULE_TARGET_TYPE\",\"$FORWARDING_RULE_LOAD_BALANCING_SCHEME\",\"$FORWARDING_RULE_IP_PROTOCOL\",\"$FORWARDING_RULE_IP\",\"$FORWARDING_RULE_PORT_RANGE\""
}

# Function to print fixed console output
print_fixed_console_output() {
    echo "Project ID: $PROJECT_ID"
    echo "Project Name: $PROJECT_NAME"
    echo "Project Application: $PROJECT_APPLICATION"
    echo "Project Owner: $PROJECT_OWNER"
    echo "Forwarding Rule Name: $FORWARDING_RULE_NAME"
    echo "Forwarding Rule Description: $FORWARDING_RULE_DESCRIPTION"
    echo "Forwarding Rule Load Balancing Type: $FORWARDING_RULE_LOAD_BALANCER_TYPE"
    echo "Forwarding Rule Target Type: $FORWARDING_RULE_TARGET_TYPE"
    echo "Forwarding Rule Load Balancing Scheme: $FORWARDING_RULE_LOAD_BALANCING_SCHEME"
    echo "Forwarding Rule IP Protocol: $FORWARDING_RULE_IP_PROTOCOL"
    echo "Forwarding Rule IP: $FORWARDING_RULE_IP"
    echo "Forwarding Rule Port Range: $FORWARDING_RULE_PORT_RANGE"
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
    FORWARDING_RULE_DESCRIPTION_UNENCODED=$(jq -r -c '.description // ""' <<< "$FORWARDING_RULE")
    FORWARDING_RULE_IP=$(jq -r -c '.IPAddress // ""' <<< "$FORWARDING_RULE")
    FORWARDING_RULE_IP_PROTOCOL=$(jq -r -c '.IPProtocol // ""' <<< "$FORWARDING_RULE")
    FORWARDING_RULE_PORT_RANGE=$(jq -r -c '.portRange // ""' <<< "$FORWARDING_RULE")
    FORWARDING_RULE_LOAD_BALANCING_SCHEME=$(jq -r -c '.loadBalancingScheme // ""' <<< "$FORWARDING_RULE")
    FORWARDING_RULE_SCOPE=$(jq -r 'if has("region") then "Regional" else "Global" end' <<< "$FORWARDING_RULE")

    FORWARDING_RULE_DESCRIPTION=$(encode_double_quotes "$FORWARDING_RULE_DESCRIPTION_UNENCODED")

    FORWARDING_RULE_TARGET=$(jq -r '
    if has("target") then
        .target
    elif has("backendService") then
        .backendService
    elif has("targetPool") then
        .targetPool
    else
        ""
    end
    ' <<< "$FORWARDING_RULE")

    FORWARDING_RULE_TARGET_TYPE=$(jq -r '
    if has("target") then
        .target | split("/") | .[-2]
    elif has("backendService") then
        "backendService"
    elif has("targetPool") then
        "targetPool"
    else
        "Unknown"
    end
    ' <<< "$FORWARDING_RULE")

    FORWARDING_RULE_LOAD_BALANCER_TYPE="Unknown: Open an issue on GitHub"

    if [[ $FORWARDING_RULE_LOAD_BALANCING_SCHEME == "EXTERNAL_MANAGED" ]]; then
        if [[ $FORWARDING_RULE_TARGET_TYPE == "targetHttpsProxies" ]]; then
            if [[ $FORWARDING_RULE_SCOPE == "Regional" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Regional External HTTPS Application Load Balancer"
            elif [[ $FORWARDING_RULE_SCOPE == "Global" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Global External HTTPS Application Load Balancer"
            fi
        elif [[ $FORWARDING_RULE_TARGET_TYPE == "targetHttpProxies" ]]; then
            if [[ $FORWARDING_RULE_SCOPE == "Regional" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Regional External HTTP Application Load Balancer"
            elif [[ $FORWARDING_RULE_SCOPE == "Global" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Global External HTTP Application Load Balancer"
            fi
        elif [[ $FORWARDING_RULE_TARGET_TYPE == "targetSslProxies" ]]; then
            FORWARDING_RULE_LOAD_BALANCER_TYPE="Global External Proxy TLS Network Load Balancer"
        elif [[ $FORWARDING_RULE_TARGET_TYPE == "targetTcpProxies" ]]; then
            if [[ $FORWARDING_RULE_SCOPE == "Regional" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Regional External Proxy TCP Network Load Balancer"
            elif [[ $FORWARDING_RULE_SCOPE == "Global" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Global External Proxy TCP Network Load Balancer"
            fi
        fi
    elif [[ $FORWARDING_RULE_LOAD_BALANCING_SCHEME == "EXTERNAL" ]]; then
        if [[ $FORWARDING_RULE_TARGET_TYPE == "targetHttpsProxies" ]]; then
            if [[ $FORWARDING_RULE_SCOPE == "Regional" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Regional External Classic HTTPS Application Load Balancer"
            elif [[ $FORWARDING_RULE_SCOPE == "Global" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Global External Classic HTTPS Application Load Balancer"
            fi
        elif [[ $FORWARDING_RULE_TARGET_TYPE == "targetHttpProxies" ]]; then
            if [[ $FORWARDING_RULE_SCOPE == "Regional" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Regional External Classic HTTP Application Load Balancer"
            elif [[ $FORWARDING_RULE_SCOPE == "Global" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Global External Classic HTTP Application Load Balancer"
            fi
        elif [[ $FORWARDING_RULE_TARGET_TYPE == "targetSslProxies" ]]; then
            if [[ $FORWARDING_RULE_SCOPE == "Regional" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Regional External Classic TLS Network Load Balancer"
            elif [[ $FORWARDING_RULE_SCOPE == "Global" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Global External Classic TLS Network Load Balancer"
            fi
        elif [[ $FORWARDING_RULE_TARGET_TYPE == "targetTcpProxies" ]]; then
            if [[ $FORWARDING_RULE_SCOPE == "Regional" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Regional External Classic TCP Network Load Balancer"
            elif [[ $FORWARDING_RULE_SCOPE == "Global" ]]; then
                FORWARDING_RULE_LOAD_BALANCER_TYPE="Global External Classic TCP Network Load Balancer"
            fi
        elif [[ $FORWARDING_RULE_TARGET_TYPE == "backendService" ]]; then
            FORWARDING_RULE_LOAD_BALANCER_TYPE="External Passthrough Network Load Balancer"
        elif [[ $FORWARDING_RULE_TARGET_TYPE == "targetPools" ]]; then
            FORWARDING_RULE_LOAD_BALANCER_TYPE="External Passthrough Network Load Balancer"
        elif [[ $FORWARDING_RULE_TARGET_TYPE == "targetVpnGateways" ]]; then
            FORWARDING_RULE_LOAD_BALANCER_TYPE="VPN Gateway"
        fi
    elif [[ $FORWARDING_RULE_LOAD_BALANCING_SCHEME == "INTERNAL_MANAGED" ]]; then
        if [[ $FORWARDING_RULE_TARGET_TYPE == "targetHttpsProxies" ]]; then
            FORWARDING_RULE_LOAD_BALANCER_TYPE="Regional Internal HTTPS Application Load Balancer"
        elif [[ $FORWARDING_RULE_TARGET_TYPE == "targetHttpProxies" ]]; then
            FORWARDING_RULE_LOAD_BALANCER_TYPE="Regional Internal HTTP Application Load Balancer"
        elif [[ $FORWARDING_RULE_TARGET_TYPE == "targetTcpProxies" ]]; then
            FORWARDING_RULE_LOAD_BALANCER_TYPE="Regional Internal TCP Load Balancer"
        fi    
    elif [[ $FORWARDING_RULE_LOAD_BALANCING_SCHEME == "INTERNAL" ]]; then
        if [[ $FORWARDING_RULE_TARGET_TYPE == "backendService" ]]; then
            FORWARDING_RULE_LOAD_BALANCER_TYPE="Regional Internal Passthrough Network Load Balancer"
        fi
    elif [[ $FORWARDING_RULE_LOAD_BALANCING_SCHEME == "INTERNAL_SELF_MANAGED" ]]; then
        if [[ $FORWARDING_RULE_TARGET_TYPE == "targetHttpProxy" || $FORWARDING_RULE_TARGET_TYPE == "targetGrpcProxy" ]]; then
            FORWARDING_RULE_LOAD_BALANCER_TYPE="Global Traffic Director"
        fi
    fi

    if [[ $FORWARDING_RULE_TARGET_TYPE == "serviceAttachments" ]]; then
        FORWARDING_RULE_LOAD_BALANCER_TYPE="Private Service Connect"
    fi
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

    get_project_details $PROJECT_ID
    FORWARDING_RULES=$(get_forwarding_rules "$PROJECT_ID")
    debug_json "Forwarding Rules" "$PROJECT_ID" "$FORWARDING_RULES"
    parse_forwarding_rules "$PROJECT_ID" "$FORWARDING_RULES"
    sleep "$SLEEP_SECONDS"

done

# Delete error log file if empty
delete_empty_error_log "$ERROR_LOG_FILE"