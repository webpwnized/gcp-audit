#!/bin/bash

source functions.inc

PROJECT_IDS="";
DEBUG="False";
HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 		set -- "$@" "-h" ;;
    "--debug") 		set -- "$@" "-d" ;;
    "--project")   	set -- "$@" "-p" ;;
    *)        		set -- "$@" "$arg"
  esac
done

while getopts "hdp:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_IDS=${OPTARG};;
        d)
        	DEBUG="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

declare SEPARATOR="----------------------------------------------------------------------------------------";

for PROJECT_ID in $PROJECT_IDS; do

	gcloud config set project $PROJECT_ID 2>/dev/null;

	if ! api_enabled compute.googleapis.com; then
		echo "Compute Engine API is not enabled on Project $PROJECT_ID"
		continue
	fi

	declare RESULTS=$(gcloud compute firewall-rules list --quiet --format="json");

	if [[ $RESULTS != "[]" ]]; then
		
		# Get the project details
		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

		echo $SEPARATOR;
		echo "Firewall rules for project $PROJECT_ID";
		echo "";
		
		#Loop through each firewall rule in the project
		echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r FIREWALL_RULE;do

			# Debugging output
			if [[ $DEBUG == "True" ]]; then
				echo $FIREWALL_RULE | jq '.';
			fi;

			ALLOWED_PROTOCOLS_LABEL="";
			DENIED_PROTOCOLS_LABEL="";
		
			NAME=$(echo $FIREWALL_RULE | jq -rc '.name');
			ALLOWED_PROTOCOLS=$(echo $FIREWALL_RULE | jq -rc '.allowed');
			DENIED_PROTOCOLS=$(echo $FIREWALL_RULE | jq -rc '.denied');
			DIRECTION=$(echo $FIREWALL_RULE | jq -rc '.direction');
			LOG_CONFIG=$(echo $FIREWALL_RULE | jq -rc '.logConfig.enable');
			SOURCE_RANGES=$(echo $FIREWALL_RULE | jq -rc '.sourceRanges');
			SOURCE_TAGS=$(echo $FIREWALL_RULE | jq -rc '.sourceTags');
			DEST_RANGES=$(echo $FIREWALL_RULE | jq -rc '.destinationRanges');
			DEST_TAGS=$(echo $FIREWALL_RULE | jq -rc '.sourceTags');
			DISABLED=$(echo $FIREWALL_RULE | jq -rc '.disabled');
			HAS_INTERNET_SOURCE=$(echo $SOURCE_RANGES | jq '.[]' | jq 'select(. | contains("0.0.0.0/0"))');
			if [[ $ALLOWED_PROTOCOLS != "null" ]]; then ALLOWED_PROTOCOLS_LABEL="ALLOWED"; fi;
			if [[ $DENIED_PROTOCOLS != "null" ]]; then DENIED_PROTOCOLS_LABEL="DENIED"; fi;

			# Print Project Information
			echo "Name: $NAME ($DIRECTION $ALLOWED_PROTOCOLS_LABEL$DENIED_PROTOCOLS_LABEL)";
			echo "Project Name: $PROJECT_NAME";
			echo "Project Application: $PROJECT_APPLICATION";
			echo "Project Owner: $PROJECT_OWNER";

			# Print Firewall Rule Information
			if [[ $ALLOWED_PROTOCOLS != "null" ]]; then echo "Allowed Protocols: $ALLOWED_PROTOCOLS"; fi;
			if [[ $DENIED_PROTOCOLS != "null" ]]; then echo "Denied Protocols: $DENIED_PROTOCOLS"; fi;
			if [[ $SOURCE_RANGES != "null" ]]; then echo "Source Ranges: $SOURCE_RANGES"; fi;
			if [[ $SOURCE_TAGS != "null" ]]; then echo "Source Tags: $SOURCE_TAGS"; fi;
			if [[ $DEST_RANGES != "null" ]]; then echo "Destination Ranges: $DEST_RANGES"; fi;
			if [[ $DEST_TAGS != "null" ]]; then echo "Destination Tags: $DEST_TAGS"; fi;
			if [[ $LOG_CONFIG != "null" ]]; then echo "Logging: $LOG_CONFIG"; fi;
			if [[ $DISABLED != "null" ]]; then echo "Disabled: $DISABLED"; fi;
								
			# Calculate Logging Violations			
			if [[ $LOG_CONFIG == "false" ]]; then
				echo "VIOLATION: Firewall logging is not enabled";
			fi;

			# If the firewall rule allows ingress, investigate the rule
			if [[ $DIRECTION == "INGRESS" ]]; then
				# Calculate Ingress Violations

				# Check for default firewall rules, at least by name
				if [[ $NAME == "default-allow-icmp" ]]; then echo "VIOLATION: Default ICMP rule implemented"; fi;
				if [[ $NAME == "default-allow-ssh" ]]; then echo "VIOLATION: Default SSH rule implemented"; fi;
				if [[ $NAME == "default-allow-rdp" ]]; then echo "VIOLATION: Default RDP rule implemented"; fi;			
				if [[ $NAME == "default-allow-internal" ]]; then echo "VIOLATION: Default Internal rule implemented"; fi;			

				# Check for ingress rules without a specific destination
				if [[ $DEST_RANGES == "null" && $DEST_TAGS == "null" ]]; then echo "VIOLATION: An ingress firewall rule does not specify a destination or target"; fi;
				
				# Check for ingress rules that allow access from all IP addresses
				if [[ $ALLOWED_PROTOCOLS_LABEL != "" && $HAS_INTERNET_SOURCE != "" ]]; then echo "VIOLATION: Allows acccess from entire Internet"; fi;
				
				# Parse the allowed protocols
				if [[ $ALLOWED_PROTOCOLS != "null" ]]; then
					echo $ALLOWED_PROTOCOLS | jq -r -c '.[]' | while IFS='' read -r ALLOWED_PROTOCOL;do
						PROTOCOL=$(echo $ALLOWED_PROTOCOL | jq -rc '.IPProtocol');
						PORTS=$(echo $ALLOWED_PROTOCOL | jq -rc '.ports');
						ALL_PORTS="";

						# Parse banned ports
						if [[ $PORTS != "null" ]]; then
							ALL_PORTS=$(echo $PORTS | jq '.[]' | jq -rc 'index("1-65535")');
							ALLOWS_SSH=$(echo $PORTS | jq '.[]' | jq -rc 'index("22")');
							ALLOWS_RDP=$(echo $PORTS | jq '.[]' | jq -rc 'index("3389")');
							ALLOWS_HTTP=$(echo $PORTS | jq '.[]' | jq -rc 'index("80")');
						fi;
						if [[ $ALL_PORTS != "" ]]; then
							echo "VIOLATION: An ingress firewall rule allows all ports for protocol $PROTOCOL";
						fi;
						if [[ "$ALLOWS_SSH" =~ ^[0-9]+$ ]]; then 
							echo "VIOLATION: Rule includes port 22/SSH"; 
						fi;
						if [[ "$ALLOWS_RDP" =~ ^[0-9]+$ ]]; then 
							echo "VIOLATION: Rule includes port 3389/RDP"; 
						fi;
						if [[ "$ALLOWS_HTTP" =~ ^[0-9]+$ ]]; then 
							echo "VIOLATION: Rule includes port 80/HTTP"; 
						fi;
						if [[ $PROTOCOL != "tcp" && $PROTOCOL != "udp" && $PROTOCOL != "icmp" ]]; then
							echo "VIOLATION: An ingress firewall rule allows suspicious protocol $PROTOCOL";
						fi;
					done;
				fi;
				echo "";
			fi;
		done;
	else
		echo $SEPARATOR;
		echo "No firewall rules found for $PROJECT_ID";
		echo "";
	fi;
	sleep 0.5;
done;

