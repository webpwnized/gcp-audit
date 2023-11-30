#!/bin/bash

source common-constants.inc;
source functions.inc;

function initializeVariables() {
	# Variables are global scope if they are not preceeded by the local keyword
	SSL_POLICY_DETAILS="";
	SSL_POLICY_PROFILE="";
	SSL_POLICY_MIN_VERSION="";
	SSL_POLICY_CIPHER_SUITES="";
	IS_IMPLEMENTING_ENCRYPTION="False";
	IS_IMPLEMENTING_ENCRYPTION_MESSAGE="The proxy does not implement transport layer encryption";
	IS_USING_DEFAULT_POLICY="Not Applicable";
	IS_USING_DEFAULT_POLICY_MESSAGE="The proxy does not implement the default TLS policy";
	SSL_POLICY_PROFILE="None";
	IS_USING_SECURE_SSL_POLICY_PROFILE="False";
	IS_USING_SECURE_SSL_POLICY_PROFILE_MESSAGE="The SSL Policy Profile is insecure";
	IS_SSL_POLICY_MIN_VERSION_SECURE="False";
	SSL_POLICY_MIN_VERSION="None";
	SSL_POLICY_MIN_VERSION_MESSAGE="The TLS Minimum Version is insecure";
	SSL_POLICY_CIPHER_SUITES="None";
};

function debugProjects() {
	# Variables are global scope if they are not preceeded by the local keyword
	echo "Project ID: $PROJECT_ID";
	echo $BLANK_LINE;
	echo "Projects";
	echo $PROJECTS;
	echo $BLANK_LINE;
};

function debugProxy() {
	echo "$PROXY_TYPE (JSON): $PROXY";
	echo $BLANK_LINE;
};

function debugSSLPolicy() {
	echo "SSL Policy (JSON): $SSL_POLICY";
	echo $BLANK_LINE;
};

function debugSSLPolicyDetails() {
	echo "SSL Policy Details (JSON): $SSL_POLICY_DETAILS";
	echo $BLANK_LINE;
};

function printOutput() {
	# Variables are global scope if they are not preceeded by the local keyword
	if [[ $CSV != "True" ]]; then
		echo "Project Name: $PROJECT_NAME";
		echo "Project Application: $PROJECT_APPLICATION";
		echo "Project Owner: $PROJECT_OWNER";
		echo "Proxy Name: $PROXY_NAME";
		echo "Proxy Type: $PROXY_TYPE";
		echo "Encryption Status: $IS_IMPLEMENTING_ENCRYPTION_MESSAGE";
		echo "Default Policy Status: $IS_USING_DEFAULT_POLICY_MESSAGE";
		echo "TLS Policy Name: $SSL_POLICY_NAME";
		echo "TLS Policy Profile: $SSL_POLICY_PROFILE";
		echo "TLS Policy Status: $IS_USING_SECURE_SSL_POLICY_PROFILE_MESSAGE";
		echo "TLS Policy Minimum Version: $SSL_POLICY_MIN_VERSION";
		echo "TLS Policy Minimum Version Status: $SSL_POLICY_MIN_VERSION_MESSAGE";
		echo "TLS Ciphers: $SSL_POLICY_CIPHER_SUITES";		
		echo $BLANK_LINE;
	else
		echo "\"$PROJECT_NAME\", \"$PROJECT_APPLICATION\", \"$PROJECT_OWNER\", \"$PROXY_NAME\", \"$PROXY_TYPE\", \"$SSL_POLICY_NAME\", \"$SSL_POLICY_MIN_VERSION\", \"$IS_IMPLEMENTING_ENCRYPTION\", \"$IS_USING_DEFAULT_POLICY\", \"$IS_USING_SECURE_SSL_POLICY_PROFILE\", \"$IS_SSL_POLICY_MIN_VERSION_SECURE\", \"$IS_IMPLEMENTING_ENCRYPTION_MESSAGE\", \"$IS_USING_DEFAULT_POLICY_MESSAGE\", \"$SSL_POLICY_PROFILE\", \"$IS_USING_SECURE_SSL_POLICY_PROFILE_MESSAGE\", \"$SSL_POLICY_MIN_VERSION_MESSAGE\", \"$SSL_POLICY_CIPHER_SUITES\"";
	fi; # end if $CSV != "True"
};

function printCSVHeaderRow() {
	echo "\"PROJECT_NAME\", \"PROJECT_APPLICATION\", \"PROJECT_OWNER\", \"PROXY_NAME\", \"PROXY_TYPE\", \"SSL_POLICY_NAME\", \"SSL_POLICY_MIN_VERSION\", \"IS_IMPLEMENTING_ENCRYPTION\", \"IS_USING_DEFAULT_POLICY\", \"IS_USING_SECURE_SSL_POLICY_PROFILE\", \"IS_SSL_POLICY_MIN_VERSION_SECURE\", \"IS_IMPLEMENTING_ENCRYPTION_MESSAGE\", \"IS_USING_DEFAULT_POLICY_MESSAGE\", \"SSL_POLICY_PROFILE\", \"IS_USING_SECURE_SSL_POLICY_PROFILE_MESSAGE\", \"SSL_POLICY_MIN_VERSION_MESSAGE\", \"SSL_POLICY_CIPHER_SUITES\"";
};

function processSSLPolicy() {
	# Variables are global scope if they are not preceeded by the local keyword
	IS_IMPLEMENTING_ENCRYPTION="True";
	IS_IMPLEMENTING_ENCRYPTION_MESSAGE="The proxy implements transport layer encryption";
	IS_USING_DEFAULT_POLICY="False";
	IS_USING_DEFAULT_POLICY_MESSAGE="The proxy does not implement the default TLS";
	
	SSL_POLICY_DETAILS=$(gcloud compute ssl-policies describe --quiet --format="json" $SSL_POLICY);
	
	if [[ $SSL_POLICY_DETAILS == "" ]]; then
		IS_USING_DEFAULT_POLICY="True";
		IS_USING_DEFAULT_POLICY_MESSAGE="The proxy implements the default TLS";
	fi; # end if $DEBUG == "True"
		
	if [[ $DEBUG == "True" ]]; then
		debugSSLPolicyDetails;
	fi; # end if $DEBUG == "True"
	
	SSL_POLICY_NAME=$(echo $SSL_POLICY_DETAILS | jq -rc '.name // empty');
	SSL_POLICY_PROFILE=$(echo $SSL_POLICY_DETAILS | jq -rc '.profile // empty');
	SSL_POLICY_MIN_VERSION=$(echo $SSL_POLICY_DETAILS | jq -rc '.minTlsVersion // empty');
	SSL_POLICY_CIPHER_SUITES=$(echo $SSL_POLICY_DETAILS | jq -rc '.enabledFeatures // empty');

	if [[ $SSL_POLICY_PROFILE == "COMPATIBLE" ]]; then 
		IS_USING_SECURE_SSL_POLICY_PROFILE="False";
		IS_USING_SECURE_SSL_POLICY_PROFILE_MESSAGE="The SSL Policy Profile is insecure";
	fi;

	if [[ $SSL_POLICY_PROFILE == "MODERN" || $SSL_POLICY_PROFILE == "RESTRICTED" ]]; then
		IS_USING_SECURE_SSL_POLICY_PROFILE="True";
		IS_USING_SECURE_SSL_POLICY_PROFILE_MESSAGE="The SSL Policy Profile is secure";
	fi;
	
	if [[ $SSL_POLICY_PROFILE == "CUSTOM" ]]; then
		IS_USING_SECURE_SSL_POLICY_PROFILE="Unknown";
		IS_USING_SECURE_SSL_POLICY_PROFILE_MESSAGE="The SSL Policy Profile may be secure";
	fi;
	
	if [[ $SSL_POLICY_MIN_VERSION == "TLS_1_2" ]]; then	
		IS_SSL_POLICY_MIN_VERSION_SECURE="True";
		SSL_POLICY_MIN_VERSION_MESSAGE="The TLS Minimum Version is secure";
	else
		IS_SSL_POLICY_MIN_VERSION_SECURE="False";
		SSL_POLICY_MIN_VERSION_MESSAGE="The TLS Minimum Version is insecure";
	fi; # end if $SSL_POLICY_MIN_VERSION == "TLS_1_2"
};

declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-c, --csv] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 			set -- "$@" "-h" ;;
    "--debug") 			set -- "$@" "-d" ;;
    "--csv") 			set -- "$@" "-c" ;;
    "--project")   		set -- "$@" "-p" ;;
    *)        			set -- "$@" "$arg"
  esac
done

while getopts "hdcp:" option
do 
    case "${option}"
        in
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

if [[ $PROJECT_ID == "" ]]; then
    declare PROJECTS=$(gcloud projects list --format="json");
else
    declare PROJECTS=$(gcloud projects list --format="json" --filter="name:$PROJECT_ID");
fi;

if [[ $DEBUG == "True" ]]; then
	debugProjects;
fi;

if [[ $PROJECTS != "[]" ]]; then

    if [[ $CSV == "True" ]]; then
    	printCSVHeaderRow;
    fi;

    echo $PROJECTS | jq -rc '.[]' | while IFS='' read PROJECT;do

		PROJECT_ID=$(echo $PROJECT | jq -r '.projectId');
			
		set_project $PROJECT_ID;
		
		if ! api_enabled compute.googleapis.com; then
			if [[ $CSV != "True" ]]; then
				echo "Compute Engine API is not enabled for Project $PROJECT_ID.";
			fi;
			continue;
		fi;

		# Get project details
		get_project_details $PROJECT_ID

		PROXY_TYPE="HTTP Load Balancers";
		initializeVariables;
		
		declare RESULTS=$(gcloud compute target-http-proxies list --quiet --format="json");

		if [[ $RESULTS != "[]" ]]; then
		
			echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r PROXY;do
			
				if [[ $DEBUG == "True" ]]; then
					debugProxy;
				fi; # end if $DEBUG == "True"

				PROXY_NAME=$(echo $PROXY | jq -rc '.name');
				printOutput;

			done; # looping through PROXY
			
		else # there are no results
			if [[ $CSV != "True" ]]; then
				echo "No $PROXY_TYPE found for $PROJECT_ID";
				echo $BLANK_LINE;
			fi;
		fi; # end if $RESULTS != "[]"

		
		PROXY_TYPE="TCP Load Balancers";
		initializeVariables;

		declare RESULTS=$(gcloud compute target-tcp-proxies list --quiet --format="json");

		if [[ $RESULTS != "[]" ]]; then
		
			echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r PROXY;do
			
				if [[ $DEBUG == "True" ]]; then
					debugProxy;
				fi; # end if $DEBUG == "True"

				PROXY_NAME=$(echo $PROXY | jq -rc '.name');
				printOutput;

			done; # looping through PROXY
			
		else # there are no results
			if [[ $CSV != "True" ]]; then
				echo "No $PROXY_TYPE found for $PROJECT_ID";
				echo $BLANK_LINE;
			fi;
		fi; # end if $RESULTS != "[]"


		PROXY_TYPE="TLS (SSL) Load Balancers";
		initializeVariables;

		declare RESULTS=$(gcloud compute target-ssl-proxies list --quiet --format="json");

		if [[ $RESULTS != "[]" ]]; then

			echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r PROXY;do

				if [[ $DEBUG == "True" ]]; then
					debugProxy;
				fi; # end if $DEBUG == "True"
				
				PROXY_NAME=$(echo $PROXY | jq -rc '.name');
				SSL_POLICY=$(echo $PROXY | jq -rc '.sslPolicy // empty');

				if [[ $DEBUG == "True" ]]; then
					debugSSLPolicy;
				fi; # end if $DEBUG == "True"
				
				if [[ $SSL_POLICY != "" ]]; then
					processSSLPolicy;
				fi; # end if $SSL_POLICY == ""

				printOutput;

			done; # looping through PROXY

		else # there are no results
			if [[ $CSV != "True" ]]; then
				echo "No $PROXY_TYPE found for $PROJECT_ID";
				echo $BLANK_LINE;
			fi;
		fi; # end if $RESULTS != "[]"


		PROXY_TYPE="HTTPS Load Balancers";
		initializeVariables;

		declare RESULTS=$(gcloud compute target-https-proxies list --quiet --format="json");

		if [[ $RESULTS != "[]" ]]; then

			echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r PROXY;do

				if [[ $DEBUG == "True" ]]; then
					debugProxy;
				fi; # end if $DEBUG == "True"
				
				PROXY_NAME=$(echo $PROXY | jq -rc '.name');
				SSL_POLICY=$(echo $PROXY | jq -rc '.sslPolicy // empty');

				if [[ $DEBUG == "True" ]]; then
					debugSSLPolicy;
				fi; # end if $DEBUG == "True"
				
				if [[ $SSL_POLICY != "" ]]; then
					processSSLPolicy;
				fi; # end if $SSL_POLICY == ""

				printOutput;

			done; # looping through PROXY

		else # there are no results
			if [[ $CSV != "True" ]]; then
				echo "No $PROXY_TYPE found for $PROJECT_ID";
				echo $BLANK_LINE;
			fi;
		fi; # end if $RESULTS != "[]"
		
		sleep $SLEEP_SECONDS;

    done; # looping through projects
    
else # if no projects
	if [[ $CSV != "True" ]]; then
    		echo "No projects found";
    		echo $BLANK_LINE;
	fi;
fi; # if projects

