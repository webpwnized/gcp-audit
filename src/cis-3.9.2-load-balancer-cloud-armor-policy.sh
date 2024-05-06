#!/bin/bash

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
		echo "\"PROJECT_ID\",\"HTTP_LOAD_BALANCER_NAME\",\"HTTP_LOAD_BALANCER_KIND\",\"URL_MAP_IS_REDIRECT\",\"VIOLATION_NO_CLOUD_ARMOR_POLICY\",\"VIOLATION_NO_OWASP_CRS_RULESET\",\"URL_MAP_NAME\",\"BACKEND_SERVICE_NAME\",\"BACKEND_SERVICE_DESCRIPTION\",\"BACKEND_SERVICE_PORT\",\"BACKEND_SERVICE_PORT_NAME\",\"BACKEND_SERVICE_PROTOCOL\",\"BACKEND_SERVICE_SECURITY_POLICY\",\"BACKEND_SERVICE_USED_BY\",\"POLICY_NAME\",\"POLICY_DDOS_PROTECTION_ENABLED\",\"RULE_DESCRIPTION\",\"RULE_ACTION\",\"RULE_MATCH\""
	fi
}

# Function to print CSV output
print_csv_output() {
	echo "\"$PROJECT_ID\",\"$HTTP_LOAD_BALANCER_NAME\",\"$HTTP_LOAD_BALANCER_KIND\",\"$URL_MAP_IS_REDIRECT\",\"$VIOLATION_NO_CLOUD_ARMOR_POLICY\",\"$VIOLATION_NO_OWASP_CRS_RULESET\",\"$URL_MAP_NAME\",\"$BACKEND_SERVICE_NAME\",\"$BACKEND_SERVICE_DESCRIPTION\",\"$BACKEND_SERVICE_PORT\",\"$BACKEND_SERVICE_PORT_NAME\",\"$BACKEND_SERVICE_PROTOCOL\",\"$BACKEND_SERVICE_SECURITY_POLICY\",\"$BACKEND_SERVICE_USED_BY\",\"$POLICY_NAME\",\"$POLICY_DDOS_PROTECTION_ENABLED\",\"$RULE_DESCRIPTION\",\"$RULE_ACTION\",\"$RULE_MATCH\""
}

# Function to print fixed console output
print_fixed_console_output() {
	echo "Project ID: $PROJECT_ID"
	echo "HTTP Load Balancer Name: $HTTP_LOAD_BALANCER_NAME"
	echo "HTTP Load Balancer Kind: $HTTP_LOAD_BALANCER_KIND"
	echo "URL Map is Redirect: $URL_MAP_IS_REDIRECT"
	echo "Cloud Armor Policy Present: $VIOLATION_NO_CLOUD_ARMOR_POLICY"
	echo "OWASP CRS Ruleset Present: $VIOLATION_NO_OWASP_CRS_RULESET"
	echo "URL Map Name: $URL_MAP_NAME"
	echo "Backend Service Name: $BACKEND_SERVICE_NAME"
	echo "Backend Service Description: $BACKEND_SERVICE_DESCRIPTION"
	echo "Backend Service Port: $BACKEND_SERVICE_PORT"
	echo "Backend Service Port Name: $BACKEND_SERVICE_PORT_NAME"
	echo "Backend Service Protocol: $BACKEND_SERVICE_PROTOCOL"
	echo "Backend Service Security Policy: $BACKEND_SERVICE_SECURITY_POLICY"
	echo "Backend Service Used By: $BACKEND_SERVICE_USED_BY"
	echo "Cloud Armor Policy Name: $POLICY_NAME"
	echo "DDoS Protection Enabled: $POLICY_DDOS_PROTECTION_ENABLED"
	echo "Cloud Armor Policy Rules:"
	echo "$BLANK_LINE"
}

# Function to print variable console output
print_variable_console_output() {
	echo "Rule Description: $RULE_DESCRIPTION"
	echo "Rule Action: $RULE_ACTION"
	echo "Rule Match: $RULE_MATCH"
	echo "$BLANK_LINE"
}

# Function to print a message when no rules are found
print_no_rules_output() {
	if [[ $CSV == "True" ]]; then
		print_csv_output
	else
		print_no_rules_console_output
	fi
}

# Function to print console output when no rules are found
print_no_rules_console_output() {
	print_fixed_console_output
	echo "No rules found"
	echo "$BLANK_LINE"
}

# Function to parse a rule from JSON data
parse_rule() {
    local RULE=$1

    RULE_ACTION=$(jq -rc '.action // ""' <<< "$RULE")
    RULE_DESCRIPTION=$(jq -rc '.description // ""' <<< "$RULE")
    
    if [[ $CSV == "True" ]]; then
        RULE_MATCH=$(jq -rc '.match // ""' <<< "$RULE" | sed 's/,/\\,/g')
    else
        RULE_MATCH=$(jq -rc '.match // ""' <<< "$RULE")
    fi

	if [[ $RULE_ACTION == "deny(403)" && $RULE_MATCH == *"evaluatePreconfiguredExpr"* ]]; then
        VIOLATION_NO_OWASP_CRS_RULESET="False"
    fi
}

# Function to parse Cloud Armor policy details
function parse_cloud_armor_policy() {
    local CLOUD_ARMOR_POLICY_NAME="$1"
	local POLICY_NAME=""
	local POLICY_DDOS_PROTECTION_ENABLED=""
	local POLICY_RULES=""
	local CLOUD_ARMOR_POLICIES="[]"
    RULE_ACTION=""
    RULE_DESCRIPTION=""
	RULE_MATCH=""
	VIOLATION_NO_CLOUD_ARMOR_POLICY="False"
	VIOLATION_NO_OWASP_CRS_RULESET="True"

    if [[ $CLOUD_ARMOR_POLICY_NAME == "" ]]; then
		if [[ $URL_MAP_IS_REDIRECT != "True" ]]; then
			VIOLATION_NO_CLOUD_ARMOR_POLICY="True"
		fi
		print_no_rules_output
		no_output_returned "No Cloud Armor policies associated with backend service $BACKEND_SERVICE_NAME"
		return
	else
		local CLOUD_ARMOR_POLICIES=$(gcloud compute security-policies describe "$CLOUD_ARMOR_POLICY_NAME" --format="json" 2>> "$ERROR_LOG_FILE" || echo "")
		debug_json "Cloud Armor Policies" "$PROJECT_ID" "$CLOUD_ARMOR_POLICIES"
	fi

	if [[ $CLOUD_ARMOR_POLICIES == "[]" ]]; then
		if [[ $URL_MAP_IS_REDIRECT != "True" ]]; then
			VIOLATION_NO_CLOUD_ARMOR_POLICY="True"
		fi
		print_no_rules_output
		no_output_returned "No Cloud Armor policies associated with cloud armor policy $CLOUD_ARMOR_POLICY_NAME"
	else
		echo "$CLOUD_ARMOR_POLICIES" | jq -r -c '.[]' | while IFS='' read -r CLOUD_ARMOR_POLICY; do
			debug_json "Cloud Armor Policy" "$PROJECT_ID" "$CLOUD_ARMOR_POLICY"

			POLICY_NAME=$(jq -r -e '.name // ""' <<< "$CLOUD_ARMOR_POLICY" || echo "")
			POLICY_DDOS_PROTECTION_ENABLED=$(jq -r -e '.adaptiveProtectionConfig.layer7DdosDefenseConfig.enable // "false"' <<< "$CLOUD_ARMOR_POLICY" || echo "false")
			POLICY_RULES=$(jq -r -e '.rules // "[]"' <<< "$CLOUD_ARMOR_POLICY" || echo "[]")

			if [[ $CSV == "True" ]]; then
				# Append CSV for each policy rule
				echo "$POLICY_RULES" | jq -r -c '.[]' | while IFS='' read -r RULE; do
					parse_rule "$RULE"
					print_csv_output
				done
			else
				# Print regular output
				print_fixed_console_output
				echo "$POLICY_RULES" | jq -r -c '.[]' | while IFS='' read -r RULE; do
					parse_rule "$RULE"
					print_variable_console_output
				done
			fi
		done
    fi
}

# Function to parse details of a load balancer
parse_load_balancer() {
	local HTTP_LOAD_BALANCER=$1

	HTTP_LOAD_BALANCER_NAME=$(jq -r -c '.name // ""' <<< "$HTTP_LOAD_BALANCER")
	HTTP_LOAD_BALANCER_KIND=$(jq -r -c '.kind // ""' <<< "$HTTP_LOAD_BALANCER")
	HTTP_LOAD_BALANCER_URL_MAP=$(jq -r -c '.urlMap // ""' <<< "$HTTP_LOAD_BALANCER")
}

# Function to retrieve the URL map details
get_url_map() {
	local URL_MAP_NAME=$1

	URL_MAP=$(gcloud compute url-maps describe "$URL_MAP_NAME" --format="json" 2>> "$ERROR_LOG_FILE" || echo "")
}

# Function to parse details of a URL map
parse_url_map() {
    local URL_MAP=$1

    if [[ -z $URL_MAP ]]; then
        URL_MAP_NAME=""
        URL_MAP_DEFAULT_SERVICE=""
		URL_MAP_IS_REDIRECT="False"
        no_output_returned "No URL Map associated with HTTP Load Balancer $HTTP_LOAD_BALANCER_NAME"
    else
        URL_MAP_NAME=$(jq -r -c '.name // ""' <<< "$URL_MAP")
        URL_MAP_DEFAULT_SERVICE=$(jq -r -c '.defaultService // ""' <<< "$URL_MAP")
		URL_MAP_IS_REDIRECT=$(jq -r '.defaultUrlRedirect.httpsRedirect // "False"' <<< "$URL_MAP" || echo "False")
		if [[ $URL_MAP_IS_REDIRECT == "true" ]]; then
			URL_MAP_IS_REDIRECT="True"
		fi
    fi
}

# Function to retrieve details of a backend service
function get_backend_service() {
	local BACKEND_SERVICE_NAME=$1

	if [[ $BACKEND_SERVICE_NAME == "" ]]; then
		BACKEND_SERVICE=""
		no_output_returned "No Backend Service associated with URL Map $URL_MAP_NAME"
	else
		SERVICE_TYPE=$(echo "$BACKEND_SERVICE_NAME" | awk -F'/' '{print $(NF-1)}')

		if [[ "$SERVICE_TYPE" != "backendBuckets" ]]; then
			BACKEND_SERVICE=$(gcloud compute backend-services describe "$BACKEND_SERVICE_NAME" --format="json" 2>> "$ERROR_LOG_FILE" || echo "")
		else
			BACKEND_SERVICE=""
		fi
	fi
}

# Function to parse details of a backend service
function parse_backend_service() {
	local BACKEND_SERVICE=$1

	if [[ $BACKEND_SERVICE == "" ]]; then
		BACKEND_SERVICE_NAME=""
		BACKEND_SERVICE_DESCRIPTION=""
		BACKEND_SERVICE_PORT=""
		BACKEND_SERVICE_PORT_NAME=""
		BACKEND_SERVICE_PROTOCOL=""
		BACKEND_SERVICE_SECURITY_POLICY=""
		BACKEND_SERVICE_USED_BY=""
		no_output_returned "No Backend Service associated with URL Map $URL_MAP_NAME"
	else
		BACKEND_SERVICE_NAME=$(jq -r -c '.name // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_DESCRIPTION=$(jq -r -c '.description // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_PORT=$(jq -r -c '.port // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_PORT_NAME=$(jq -r -c '.portName // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_PROTOCOL=$(jq -r -c '.protocol // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_SECURITY_POLICY=$(jq -r -c '.securityPolicy // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_USED_BY=$(jq -r -c '.usedBy[0].reference | split("/") | .[-1] // ""' <<< "$BACKEND_SERVICE")
	fi
}

# Function to retrieve the list of load balancers
get_load_balancers() {
    local LOAD_BALANCER_TYPE=$1
    local PROJECT_ID=$2
    local LOAD_BALANCERS=""

    if [[ $LOAD_BALANCER_TYPE == "HTTP" ]]; then
        LOAD_BALANCERS=$(gcloud compute target-http-proxies list --project $PROJECT_ID --quiet --format="json" 2>> "$ERROR_LOG_FILE" || echo "")
    elif [[ $LOAD_BALANCER_TYPE == "HTTPS" ]]; then
        LOAD_BALANCERS=$(gcloud compute target-https-proxies list --project $PROJECT_ID --quiet --format="json" 2>> "$ERROR_LOG_FILE" || echo "")
    fi

    echo "$LOAD_BALANCERS"
}

# Function to parse details of load balancers
parse_load_balancers() {
	local LOAD_BALANCER_TYPE=$1
	local PROJECT_ID=$2
	local LOAD_BALANCERS=$3

	if [[ $LOAD_BALANCERS == "[]" ]]; then
		no_output_returned "No $LOAD_BALANCER_TYPE Load Balancer associated with project $PROJECT_ID"
	else
		echo "$LOAD_BALANCERS" | jq -r -c '.[]' | while IFS='' read -r LOAD_BALANCER; do
			debug_json "$LOAD_BALANCER_TYPE Load Balancer" "$PROJECT_ID" "$LOAD_BALANCER"
			parse_load_balancer "$LOAD_BALANCER"
			get_url_map "$HTTP_LOAD_BALANCER_URL_MAP"
			debug_json "URL Map" "$PROJECT_ID" "$URL_MAP"
			parse_url_map "$URL_MAP"
			get_backend_service "$URL_MAP_DEFAULT_SERVICE"
			debug_json "Backend Service" "$PROJECT_ID" "$BACKEND_SERVICE"
			parse_backend_service "$BACKEND_SERVICE"
			parse_cloud_armor_policy "$BACKEND_SERVICE_SECURITY_POLICY"
		done
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

for arg in "$@"; do
  shift
  case "$arg" in
    "--help")           set -- "$@" "-h" ;;
    "--debug")          set -- "$@" "-d" ;;
    "--csv")            set -- "$@" "-c" ;;
    "--project")        set -- "$@" "-p" ;;
    *)                  set -- "$@" "$arg"
  esac
done

# Parse options and arguments
while getopts "hdcip:" option; do 
    case "${option}" in
        p)
            PROJECT_ID=${OPTARG}
            ;;
        d)
            DEBUG="True"
            ;;
        c)
            CSV="True"
            ;;
        h)
            echo $HELP 
            exit 0
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

    # Get and parse HTTP load balancers
    HTTP_LOAD_BALANCERS=$(get_load_balancers "HTTP" "$PROJECT_ID")
    debug_json "HTTP Load Balancers" "$PROJECT_ID" "$HTTP_LOAD_BALANCERS"
    parse_load_balancers "HTTP" "$PROJECT_ID" "$HTTP_LOAD_BALANCERS"

    # Get and parse HTTPS load balancers
    HTTPS_LOAD_BALANCERS=$(get_load_balancers "HTTPS" "$PROJECT_ID")
    debug_json "HTTPS Load Balancers" "$PROJECT_ID" "$HTTPS_LOAD_BALANCERS"
    parse_load_balancers "HTTPS" "$PROJECT_ID" "$HTTPS_LOAD_BALANCERS"

    sleep $SLEEP_SECONDS

done
