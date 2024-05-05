#!/bin/bash

source common-constants.inc;
source functions.inc;

function debug_projects() {
	if [[ $DEBUG == "True" ]]; then
		echo "DEBUG: Projects: $PROJECTS";
	fi;
}

function debug_load_balancer() {
	local HTTP_LOAD_BALANCER=$1

	if [[ $DEBUG == "True" ]]; then
		echo "DEBUG: HTTP Load Balancer (JSON):";
		echo "$(jq -C '.' <<< "$HTTP_LOAD_BALANCER")";
	fi;
}

function debug_url_map() {
	local URL_MAP=$1

	if [[ $DEBUG == "True" ]]; then
		echo "DEBUG: URL Map (JSON):";
		echo "$(jq -C '.' <<< "$URL_MAP")";
	fi;
}

function debug_backend_services() {
    local PROJECT_ID=$1
    local BACKEND_SERVICES=$2
    
    if [[ $DEBUG == "True" ]]; then
        echo "DEBUG: Project ID: $PROJECT_ID";
        echo "DEBUG: Backend Services (JSON):";
        echo "$(jq -C '.' <<< "$BACKEND_SERVICES")";
    fi;
}

function debug_backend_service() {
    local BACKEND_SERVICE=$1

    if [[ $DEBUG == "True" ]]; then
        echo "DEBUG: Backend Service (JSON):"
        echo "$(jq -C '.' <<< "$BACKEND_SERVICE")"
    fi
}

function debug_cloud_armor_policy() {
	local CLOUD_ARMOR_POLICY=$1

	if [[ $DEBUG == "True" ]]; then
		echo "DEBUG: Cloud Armor Policy (JSON):";
		echo "$(jq -C '.' <<< "$CLOUD_ARMOR_POLICY")";
	fi;
}

function no_output_returned() {
	local MESSAGE=$1

	if [[ $CSV != "True" ]]; then
		echo $MESSAGE;
	fi;
}

print_csv_header() {
	if [[ $CSV == "True" ]]; then
		# Print CSV header row
		echo "\"PROJECT_ID\", \"BACKEND_SERVICE_NAME\", \"BACKEND_SERVICE_DESCRIPTION\", \"BACKEND_SERVICE_PORT\", \"BACKEND_SERVICE_PORT_NAME\", \"BACKEND_SERVICE_PROTOCOL\", \"BACKEND_SERVICE_SECURITY_POLICY\", \"BACKEND_SERVICE_USED_BY\", \"CLOUD_ARMOR_POLICY_NAME\", \"DDoS_PROTECTION_ENABLED\", \"RULE_DESCRIPTION\", \"RULE_ACTION\", \"RULE_MATCH\"";
	fi;
}

function parse_rule() {
    local RULE=$1

    RULE_ACTION=$(echo "$RULE" | jq -rc '.action');
    RULE_DESCRIPTION=$(echo "$RULE" | jq -rc '.description');
	if [[ $CSV == "True" ]]; then
    	RULE_MATCH=$(echo "$RULE" | jq -rc '.match' | sed 's/,/\\,/g');
	else
		RULE_MATCH=$(echo "$RULE" | jq -rc '.match');
	fi;
}

function parse_cloud_armor_policy() {
    local CLOUD_ARMOR_POLICY_NAME="$1"

	if [[ $CLOUD_ARMOR_POLICY_NAME == "" ]]; then
		no_output_returned "No Cloud Armor policy associated with backend service $BACKEND_SERVICE_NAME";
		return;
	fi;

	local CLOUD_ARMOR_POLICIES=$(gcloud compute security-policies describe $CLOUD_ARMOR_POLICY_NAME --format="json")

	debug_cloud_armor_policy "$CLOUD_ARMOR_POLICIES";
    
    if [[ $CLOUD_ARMOR_POLICIES == "[]" ]]; then
		no_output_returned "No Cloud Armor policy associated with backend service $BACKEND_SERVICE_NAME";
	else
		echo "$CLOUD_ARMOR_POLICIES" | jq -r -c '.[]' | while IFS='' read -r CLOUD_ARMOR_POLICY; do
			local POLICY_NAME=$(echo "$CLOUD_ARMOR_POLICY" | jq -r -c '.name');
			local POLICY_DDOS_PROTECTION_ENABLED=$(echo "$CLOUD_ARMOR_POLICY" | jq -r -c '.adaptiveProtectionConfig.layer7DdosDefenseConfig.enable');
			local POLICY_RULES=$(echo "$CLOUD_ARMOR_POLICY" | jq -r -c '.rules');

			if [[ $CSV == "True" ]]; then

				# Append CSV for each policy rule
				echo "$POLICY_RULES" | jq -r -c '.[]' | while IFS='' read -r RULE; do
					parse_rule "$RULE";
					echo \"$PROJECT_ID\", \"$BACKEND_SERVICE_NAME\", \"$BACKEND_SERVICE_DESCRIPTION\", \"$BACKEND_SERVICE_PORT\", \"$BACKEND_SERVICE_PORT_NAME\", \"$BACKEND_SERVICE_PROTOCOL\", \"$BACKEND_SERVICE_SECURITY_POLICY\", \"$BACKEND_SERVICE_USED_BY\", \"$POLICY_NAME\", \"$POLICY_DDOS_PROTECTION_ENABLED\", \"$RULE_DESCRIPTION\", \"$RULE_ACTION\", \"$RULE_MATCH\";
				done;
			else
				# Print regular output
				echo "Project ID: $PROJECT_ID"
				echo "Backend Service Name: $BACKEND_SERVICE_NAME"
				echo "Backend Service Description: $BACKEND_SERVICE_DESCRIPTION"
				echo "Backend Service Port: $BACKEND_SERVICE_PORT"
				echo "Backend Service Port Name: $BACKEND_SERVICE_PORT_NAME"
				echo "Backend Service Protocol: $BACKEND_SERVICE_PROTOCOL"
				echo "Backend Service Security Policy: $BACKEND_SERVICE_SECURITY_POLICY"
				echo "Backend Service Used By: $BACKEND_SERVICE_USED_BY"
				echo "Cloud Armor Policy Name: $POLICY_NAME";
				echo "DDoS Protection Enabled: $POLICY_DDOS_PROTECTION_ENABLED";
				echo "Cloud Armor Policy Rules:";
				echo "$POLICY_RULES" | jq -r -c '.[]' | while IFS='' read -r RULE; do
					parse_rule "$RULE";
					echo $BLANK_LINE;
					echo "Rule Description: $RULE_DESCRIPTION";
					echo "Rule Action: $RULE_ACTION";
					echo "Rule Match: $RULE_MATCH";
				done;
				echo $BLANK_LINE;
			fi;
		done;
    fi;
}

function parse_load_balancer() {
	local HTTP_LOAD_BALANCER=$1

	HTTP_LOAD_BALANCER_NAME=$(echo "$HTTP_LOAD_BALANCER" | jq -r -c '.name');
	HTTP_LOAD_BALANCER_KIND=$(echo "$HTTP_LOAD_BALANCER" | jq -r -c '.kind');
	HTTP_LOAD_BALANCER_URL_MAP=$(echo "$HTTP_LOAD_BALANCER" | jq -r -c '.urlMap | split("/") | .[-1] // ""');
}

function get_url_map() {
	local URL_MAP_NAME=$1

	URL_MAP=$(gcloud compute url-maps describe "$URL_MAP_NAME" --format="json" 2>/dev/null || echo "");
}

parse_url_map() {
	local URL_MAP=$1

	URL_MAP_NAME="";
	URL_MAP_DEFAULT_SERVICE="";

	if [[ $URL_MAP == "" ]]; then
		no_output_returned "No URL Map associated with HTTP Load Balancer $HTTP_LOAD_BALANCER_NAME";
	else
		URL_MAP_NAME=$(echo "$URL_MAP" | jq -r -c '.name');
		URL_MAP_DEFAULT_SERVICE=$(echo "$URL_MAP" | jq -r -c '.defaultService // ""' | awk -F '/' '{print $NF}');
	fi;
}

function get_backend_service() {
	local BACKEND_SERVICE_NAME=$1

	BACKEND_SERVICE="";

	if [[ $BACKEND_SERVICE_NAME == "" ]]; then
		no_output_returned "No Backend Service associated with URL Map $URL_MAP_NAME";
	else
		BACKEND_SERVICE=$(gcloud compute backend-services describe $BACKEND_SERVICE_NAME --format="json");
	fi;
}

function parse_backend_service() {
	local BACKEND_SERVICE=$1

	BACKEND_SERVICE_NAME="";
	BACKEND_SERVICE_DESCRIPTION="";
	BACKEND_SERVICE_PORT="";
	BACKEND_SERVICE_PORT_NAME="";
	BACKEND_SERVICE_PROTOCOL="";
	BACKEND_SERVICE_SECURITY_POLICY="";
	BACKEND_SERVICE_USED_BY="";

	if [[ $BACKEND_SERVICE == "" ]]; then
		no_output_returned "No Backend Service associated with URL Map $URL_MAP_NAME";
	else
		BACKEND_SERVICE_NAME=$(echo "$BACKEND_SERVICE" | jq -r -c '.name // ""');
		BACKEND_SERVICE_DESCRIPTION=$(echo "$BACKEND_SERVICE" | jq -r -c '.description // ""');
		BACKEND_SERVICE_PORT=$(echo "$BACKEND_SERVICE" | jq -r -c '.port // ""');
		BACKEND_SERVICE_PORT_NAME=$(echo "$BACKEND_SERVICE" | jq -r -c '.portName // ""');
		BACKEND_SERVICE_PROTOCOL=$(echo "$BACKEND_SERVICE" | jq -r -c '.protocol // ""');
		BACKEND_SERVICE_SECURITY_POLICY=$(echo "$BACKEND_SERVICE" | jq -r -c '.securityPolicy | split("/") | .[-1] // ""');
		BACKEND_SERVICE_USED_BY=$(echo "$BACKEND_SERVICE" | jq -r -c '.usedBy[0].reference | split("/") | .[-1] // ""');
	fi;
}

get_load_balancers() {
	local LOAD_BALANCER_TYPE=$1
	local PROJECT_ID=$2

	if [[ $LOAD_BALANCER_TYPE == "HTTP" ]]; then
		HTTP_LOAD_BALANCERS=$(gcloud compute target-http-proxies list --project $PROJECT_ID --quiet --format="json");
	elif [[ $LOAD_BALANCER_TYPE == "HTTPS" ]]; then
		HTTPS_LOAD_BALANCERS=$(gcloud compute target-https-proxies list --project $PROJECT_ID --quiet --format="json");
	fi;
}

debug_load_balancers() {
	local LOAD_BALANCER_TYPE=$1
	local LOAD_BALANCERS=$2

	if [[ $DEBUG == "True" ]]; then
		echo "DEBUG: $LOAD_BALANCER_TYPE Load Balancers (JSON):";
		echo "$(jq -C '.' <<< "$LOAD_BALANCERS")";
	fi;
}

parse_load_balancers () {
	local LOAD_BALANCER_TYPE=$1
	local HTTP_LOAD_BALANCERS=$2

	if [[ $HTTP_LOAD_BALANCERS == "[]" ]]; then
		no_output_returned "No $LOAD_BALANCER_TYPE Load Balancer associated with project $PROJECT_ID";
	else
		echo "$HTTP_LOAD_BALANCERS" | jq -r -c '.[]' | while IFS='' read -r HTTP_LOAD_BALANCER; do
			debug_load_balancer "$HTTP_LOAD_BALANCER";
			parse_load_balancer "$HTTP_LOAD_BALANCER";
			get_url_map "$HTTP_LOAD_BALANCER_URL_MAP";
			debug_url_map "$URL_MAP";
			parse_url_map "$URL_MAP";
			get_backend_service "$URL_MAP_DEFAULT_SERVICE";
			debug_backend_service "$BACKEND_SERVICE";
			parse_backend_service "$BACKEND_SERVICE";
			parse_cloud_armor_policy "$BACKEND_SERVICE_SECURITY_POLICY";
		done;
	fi;
}

declare DEBUG="False";
declare CSV="False";
declare PROJECT_ID="";
declare PROJECTS="";
declare HELP=$(cat << EOL
    $0 [-p, --project PROJECT] [-c, --csv] [-d, --debug] [-h, --help]
EOL
);

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

while getopts "hdcip:" option; do 
    case "${option}" in
        p)
            PROJECT_ID=${OPTARG};;
        d)
            DEBUG="True";;
        c)
            CSV="True";;
        h)
            echo $HELP; 
            exit 0;;
    esac;
done;

declare PROJECTS=$(get_projects "$PROJECT_ID");

if [[ $PROJECTS == "[]" ]]; then
    echo "No projects found";
    echo $BLANK_LINE;
    exit 0;
fi;

debug_projects;

print_csv_header;

for PROJECT_ID in $PROJECTS; do

    if ! api_enabled compute.googleapis.com; then
		no_output_returned "Compute Engine API is not enabled for Project $PROJECT_ID.";
        continue;
    fi;

	HTTP_LOAD_BALANCERS=$(gcloud compute target-http-proxies list --quiet --format="json");
	HTTPS_LOAD_BALANCERS=$(gcloud compute target-https-proxies list --quiet --format="json");

	get_load_balancers "HTTP" "$PROJECT_ID";
	debug_load_balancers "HTTP" "$HTTP_LOAD_BALANCERS";
	parse_load_balancers "HTTP" "$HTTP_LOAD_BALANCERS";
	
	get_load_balancers "HTTPS""$PROJECT_ID";
	debug_load_balancers "HTTPS" "$HTTPS_LOAD_BALANCERS";
	parse_load_balancers "HTTPS" "$HTTPS_LOAD_BALANCERS";

    sleep $SLEEP_SECONDS;
done;
