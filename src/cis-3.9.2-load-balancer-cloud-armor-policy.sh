#!/bin/bash

source common-constants.inc;
source functions.inc;

function debug_projects() {
	if [[ $DEBUG == "True" ]]; then
		echo "DEBUG: Projects: $PROJECTS";
	fi;
}

debug_json() {
	local DATA_TYPE=$1
	local PROJECT_ID=$2
	local JSON_DATA=$3

	if [[ $DEBUG == "True" ]]; then
		echo "PROJECT: $PROJECT_ID:"
		echo "DEBUG: $DATA_TYPE (JSON):"
		echo "$(jq -C '.' <<< "$JSON_DATA")"
	fi
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
		echo "\"PROJECT_ID\", \"HTTP_LOAD_BALANCER_NAME\", \"HTTP_LOAD_BALANCER_KIND\", \"URL_MAP_NAME\", \"BACKEND_SERVICE_NAME\", \"BACKEND_SERVICE_DESCRIPTION\", \"BACKEND_SERVICE_PORT\", \"BACKEND_SERVICE_PORT_NAME\", \"BACKEND_SERVICE_PROTOCOL\", \"BACKEND_SERVICE_SECURITY_POLICY\", \"BACKEND_SERVICE_USED_BY\", \"POLICY_NAME\", \"POLICY_DDOS_PROTECTION_ENABLED\", \"RULE_DESCRIPTION\", \"RULE_ACTION\", \"RULE_MATCH\"";
	fi;
}

print_csv_output() {
	echo "\"$PROJECT_ID\",
	\"$HTTP_LOAD_BALANCER_NAME\",
	\"$HTTP_LOAD_BALANCER_KIND\",
	\"$URL_MAP_NAME\",
	\"$BACKEND_SERVICE_NAME\",
	\"$BACKEND_SERVICE_DESCRIPTION\",
	\"$BACKEND_SERVICE_PORT\",
	\"$BACKEND_SERVICE_PORT_NAME\",
	\"$BACKEND_SERVICE_PROTOCOL\",
	\"$BACKEND_SERVICE_SECURITY_POLICY\",
	\"$BACKEND_SERVICE_USED_BY\",
	\"$POLICY_NAME\",
	\"$POLICY_DDOS_PROTECTION_ENABLED\",
	\"$RULE_DESCRIPTION\",
	\"$RULE_ACTION\",
	\"$RULE_MATCH\"";
}

print_fixed_console_output() {
	echo "Project ID: $PROJECT_ID"
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

print_variable_console_output() {
	echo "Rule Description: $RULE_DESCRIPTION"
	echo "Rule Action: $RULE_ACTION"
	echo "Rule Match: $RULE_MATCH"
	echo "$BLANK_LINE"
}

print_no_rule_console_output() {
	print_fixed_console_output
	echo "No rules found"
	echo "$BLANK_LINE"
}

parse_rule() {
    local RULE=$1

    RULE_ACTION=$(jq -rc '.action // ""' <<< "$RULE")
    RULE_DESCRIPTION=$(jq -rc '.description // ""' <<< "$RULE")
    
    if [[ $CSV == "True" ]]; then
        RULE_MATCH=$(jq -rc '.match // ""' <<< "$RULE" | sed 's/,/\\,/g')
    else
        RULE_MATCH=$(jq -rc '.match // ""' <<< "$RULE")
    fi
}

function parse_cloud_armor_policy() {
    local CLOUD_ARMOR_POLICY_NAME="$1"
	local POLICY_NAME="";
	local POLICY_DDOS_PROTECTION_ENABLED="";
	local POLICY_RULES="";
    RULE_ACTION="";
    RULE_DESCRIPTION="";
	RULE_MATCH="";

	local CLOUD_ARMOR_POLICIES=$(gcloud compute security-policies describe $CLOUD_ARMOR_POLICY_NAME --format="json")

	debug_json "Cloud Armor Policy" "$PROJECT_ID" "$CLOUD_ARMOR_POLICIES";
    
    if [[ $CLOUD_ARMOR_POLICIES == "[]" ]]; then
		print_no_rule_console_output
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
					print_csv_output;
				done;
			else
				# Print regular output
				print_fixed_console_output;
				echo "$POLICY_RULES" | jq -r -c '.[]' | while IFS='' read -r RULE; do
					parse_rule "$RULE";
					print_variable_console_output;
				done;
			fi;
		done;
    fi;
}

parse_load_balancer() {
	local HTTP_LOAD_BALANCER=$1

	HTTP_LOAD_BALANCER_NAME=$(jq -r -c '.name // ""' <<< "$HTTP_LOAD_BALANCER")
	HTTP_LOAD_BALANCER_KIND=$(jq -r -c '.kind // ""' <<< "$HTTP_LOAD_BALANCER")
	HTTP_LOAD_BALANCER_URL_MAP=$(jq -r -c '.urlMap | split("/") | .[-1] // ""' <<< "$HTTP_LOAD_BALANCER")
}

get_url_map() {
	local URL_MAP_NAME=$1

	URL_MAP=$(gcloud compute url-maps describe "$URL_MAP_NAME" --format="json" || echo "")
}

parse_url_map() {
    local URL_MAP=$1

    if [[ $URL_MAP == "" ]]; then
        URL_MAP_NAME=""
        URL_MAP_DEFAULT_SERVICE=""
        no_output_returned "No URL Map associated with HTTP Load Balancer $HTTP_LOAD_BALANCER_NAME";
    else
        URL_MAP_NAME=$(echo "$URL_MAP" | jq -r -c '.name');
        URL_MAP_DEFAULT_SERVICE=$(echo "$URL_MAP" | jq -r -c '.defaultService // ""' | awk -F '/' '{print $NF}');
    fi;
}

function get_backend_service() {
	local BACKEND_SERVICE_NAME=$1

	if [[ $BACKEND_SERVICE_NAME == "" ]]; then
		BACKEND_SERVICE="";
		no_output_returned "No Backend Service associated with URL Map $URL_MAP_NAME";
	else
		BACKEND_SERVICE=$(gcloud compute backend-services describe $BACKEND_SERVICE_NAME --format="json");
	fi;
}

function parse_backend_service() {
	local BACKEND_SERVICE=$1

	if [[ $BACKEND_SERVICE == "" ]]; then
		BACKEND_SERVICE_NAME="";
		BACKEND_SERVICE_DESCRIPTION="";
		BACKEND_SERVICE_PORT="";
		BACKEND_SERVICE_PORT_NAME="";
		BACKEND_SERVICE_PROTOCOL="";
		BACKEND_SERVICE_SECURITY_POLICY="";
		BACKEND_SERVICE_USED_BY="";
		no_output_returned "No Backend Service associated with URL Map $URL_MAP_NAME";
	else
		BACKEND_SERVICE_NAME=$(jq -r -c '.name // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_DESCRIPTION=$(jq -r -c '.description // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_PORT=$(jq -r -c '.port // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_PORT_NAME=$(jq -r -c '.portName // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_PROTOCOL=$(jq -r -c '.protocol // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_SECURITY_POLICY=$(jq -r -c '.securityPolicy // ""' <<< "$BACKEND_SERVICE")
		BACKEND_SERVICE_USED_BY=$(jq -r -c '.usedBy[0].reference | split("/") | .[-1] // ""' <<< "$BACKEND_SERVICE")
	fi;
}

get_load_balancers() {
    local LOAD_BALANCER_TYPE=$1
    local PROJECT_ID=$2
    local LOAD_BALANCERS=""

    if [[ $LOAD_BALANCER_TYPE == "HTTP" ]]; then
        LOAD_BALANCERS=$(gcloud compute target-http-proxies list --project $PROJECT_ID --quiet --format="json" || echo "")
    elif [[ $LOAD_BALANCER_TYPE == "HTTPS" ]]; then
        LOAD_BALANCERS=$(gcloud compute target-https-proxies list --project $PROJECT_ID --quiet --format="json" || echo "")
    fi

    echo "$LOAD_BALANCERS"
}

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
			debug_json "Cloud Armor Policy" "$PROJECT_ID" "$CLOUD_ARMOR_POLICIES"
		done
	fi
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

	# Call the function to get HTTP load balancers for a specific project
	HTTP_LOAD_BALANCERS=$(get_load_balancers "HTTP" "$PROJECT_ID")
	debug_json "HTTP Load Balancers" "$PROJECT_ID" "$HTTP_LOAD_BALANCERS";
	parse_load_balancers "HTTP" "$PROJECT_ID" "$HTTP_LOAD_BALANCERS";
	
	# Call the function to get HTTPS load balancers for a specific project
	HTTPS_LOAD_BALANCERS=$(get_load_balancers "HTTPS" "$PROJECT_ID")
	debug_json "HTTPS Load Balancers" "$PROJECT_ID" "$HTTPS_LOAD_BALANCERS";
	parse_load_balancers "HTTPS" "$PROJECT_ID" "$HTTPS_LOAD_BALANCERS";

    sleep $SLEEP_SECONDS;
done;
