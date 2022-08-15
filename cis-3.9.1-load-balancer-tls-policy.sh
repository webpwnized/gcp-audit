#!/bin/bash

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
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

declare SEPARATOR="----------------------------------------------------------------------------------------";

for PROJECT_ID in $PROJECT_IDS; do

	gcloud config set project $PROJECT_ID;
	
	PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
	PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
	PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
	PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

	echo "";
	echo $SEPARATOR;
	echo "Project Name: $PROJECT_NAME";
	echo "Project Application: $PROJECT_APPLICATION";
	echo "Project Owner: $PROJECT_OWNER";
	echo "";

	declare RESULTS=$(gcloud compute target-http-proxies list --quiet --format="json");

	if [[ $RESULTS != "[]" ]]; then
		
		echo $SEPARATOR;
		echo "Insecure HTTP Load Balancers for project $PROJECT_ID";
		echo $SEPARATOR;
		echo "";
		
		echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r HTTP_PROXY;do
			NAME=$(echo $HTTP_PROXY | jq -rc '.name');
			echo "Name: $NAME (Insecure)";
		done;
		echo "";
	else
		echo $SEPARATOR;
		echo "No HTTP Load Balancers found for $PROJECT_ID";
		echo "";
	fi;
	
	declare RESULTS=$(gcloud compute target-tcp-proxies list --quiet --format="json");

	if [[ $RESULTS != "[]" ]]; then
		
		echo $SEPARATOR;
		echo "Insecure TCP Load Balancers for project $PROJECT_ID";
		echo $SEPARATOR;
		echo "";
		
		echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r TCP_PROXY;do
			NAME=$(echo $TCP_PROXY | jq -rc '.name');
			echo "Name: $NAME (Insecure)";
		done;
		echo "";
	else
		echo $SEPARATOR;
		echo "No TCP Load Balancers found for $PROJECT_ID";
		echo "";
	fi;

	declare RESULTS=$(gcloud compute target-ssl-proxies list --quiet --format="json");

	if [[ $RESULTS != "[]" ]]; then
		
		echo $SEPARATOR;
		echo "TLS Load Balancers for project $PROJECT_ID";
		echo $SEPARATOR;
		echo "";
		
		echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r SSL_PROXY;do
			NAME=$(echo $SSL_PROXY | jq -rc '.name');
			SSL_POLICY=$(echo $SSL_PROXY | jq -rc '.sslPolicy');

			echo "Name: $NAME $DEFAULT_POLICY_VIOLATION";

			if [[ $SSL_POLICY == "null" ]]; then
				echo "VIOLATION: Using default TLS policy";
			else
				SSL_POLICY_DETAILS=$(gcloud compute ssl-policies describe --quiet --format="json" $SSL_POLICY);
				SSL_POLICY_PROFILE=$(echo $SSL_POLICY_DETAILS | jq -rc '.profile');
				SSL_POLICY_MIN_VERSION=$(echo $SSL_POLICY_DETAILS | jq -rc '.minTlsVersion');
				SSL_POLICY_CIPHER_SUITES=$(echo $SSL_POLICY_DETAILS | jq -rc '.enabledFeatures');

				if [[ $SSL_POLICY_PROFILE == "COMPATIBLE" ]]; then echo "VIOLATION: Using insecure TLS policy"; fi;
				if [[ $SSL_POLICY_PROFILE == "MODERN" ]]; then
					if [[ $SSL_POLICY_MIN_VERSION == "TLS_1_2" ]]; then
						echo "Note: Secure TLS policy detected"; 
					else
						"VIOLATION: Using insecure TLS policy"; 
					fi;
				fi;
				if [[ $SSL_POLICY_PROFILE == "RESTRICTED" ]]; then echo "Note: Secure TLS policy detected"; fi;
				if [[ $SSL_POLICY_PROFILE == "CUSTOM" ]]; then
					echo "Warning: Custom TLS policy. Insecure ciphers listed below";
					echo $SSL_POLICY_DETAILS | jq -rc '.enabledFeatures[] | select(. | test("^TLS_RSA_"))';
				fi;
			fi;
			echo "";
		done;
		echo "";
	else
		echo $SEPARATOR;
		echo "No TLS Load Balancers found for $PROJECT_ID";
		echo "";
	fi;

	declare RESULTS=$(gcloud compute target-https-proxies list --quiet --format="json");

	if [[ $RESULTS != "[]" ]]; then
		
		echo $SEPARATOR;
		echo "HTTPS Load Balancers for project $PROJECT_ID";
		echo $SEPARATOR;
		echo "";
		
		echo $RESULTS | jq -r -c '.[]' | while IFS='' read -r HTTPS_PROXY;do
			NAME=$(echo $HTTPS_PROXY | jq -rc '.name');
			SSL_POLICY=$(echo $HTTPS_PROXY | jq -rc '.sslPolicy');

			echo "Name: $NAME $DEFAULT_POLICY_VIOLATION";

			if [[ $SSL_POLICY == "null" ]]; then
				echo "VIOLATION: Using default TLS policy";
			else
				SSL_POLICY_DETAILS=$(gcloud compute ssl-policies describe --quiet --format="json" $SSL_POLICY);
				SSL_POLICY_PROFILE=$(echo $SSL_POLICY_DETAILS | jq -rc '.profile');
				SSL_POLICY_MIN_VERSION=$(echo $SSL_POLICY_DETAILS | jq -rc '.minTlsVersion');
				SSL_POLICY_CIPHER_SUITES=$(echo $SSL_POLICY_DETAILS | jq -rc '.enabledFeatures');

				if [[ $SSL_POLICY_PROFILE == "COMPATIBLE" ]]; then echo "VIOLATION: Using insecure TLS policy"; fi;
				if [[ $SSL_POLICY_PROFILE == "MODERN" ]]; then
					if [[ $SSL_POLICY_MIN_VERSION == "TLS_1_2" ]]; then
						echo "Note: Secure TLS policy detected"; 
					else
						"VIOLATION: Using insecure TLS policy"; 
					fi;
				fi;
				if [[ $SSL_POLICY_PROFILE == "RESTRICTED" ]]; then echo "Note: Secure TLS policy detected"; fi;
				if [[ $SSL_POLICY_PROFILE == "CUSTOM" ]]; then
					echo "Warning: Custom TLS policy. Insecure ciphers listed below";
					echo $SSL_POLICY_DETAILS | jq -rc '.enabledFeatures[] | select(. | test("^TLS_RSA_"))';
				fi;
			fi;
			echo "";
		done;
		echo "";
	else
		echo $SEPARATOR;
		echo "No HTTPS Load Balancers found for $PROJECT_ID";
		echo "";
	fi;
	
	sleep 0.5;

done;

